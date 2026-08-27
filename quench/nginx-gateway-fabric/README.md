# Quenchworks NGINX Gateway Fabric

[NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) is F5/NGINX's
Gateway API implementation: a control plane that watches `GatewayClass`, `Gateway`,
`HTTPRoute` and its own `gateway.nginx.org` policy CRDs, and drives a fleet of nginx
data planes it provisions itself.

This chart installs the control plane only. Everything nginx is created by the
controller, per `Gateway`, from the `NginxProxy` resource the chart ships.

Two hardened images, both built from source on Wolfi, nonroot, read-only rootfs,
0 fixable CVEs, cosign-signed with SBOM + SLSA provenance, pinned here by digest:

| image | what it is |
| --- | --- |
| `ghcr.io/quenchworks/images/nginx-gateway-fabric` | the control plane (`gateway`) |
| `ghcr.io/quenchworks/images/nginx-gateway-fabric-nginx` | the data plane: nginx + njs + nginx-agent |

## Install

The Gateway API CRDs are **not** part of this chart. They are cluster-scoped singletons
owned by the [`gateway-api-crds`](../gateway-api-crds) chart, and the controller cannot
sync its caches without them:

```sh
helm install gateway-api-crds oci://ghcr.io/quenchworks/charts/gateway-api-crds
helm install ngf oci://ghcr.io/quenchworks/charts/nginx-gateway-fabric
```

Then create a `Gateway` against the `GatewayClass` the chart made:

```sh
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF
```

On a cluster with no LoadBalancer controller (kind, bare metal without MetalLB) set
`nginx.service.type` to `NodePort` or `ClusterIP` first — a `Gateway` with no address
never reaches `Programmed=True`.

## Verify the images

```sh
cosign verify ghcr.io/quenchworks/images/nginx-gateway-fabric \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/nginx-gateway-fabric-nginx \
  --owner quenchworks
```

## Values

| key | default | notes |
| --- | --- | --- |
| `image.repository` / `image.digest` | control-plane image, by digest | never a tag |
| `nginx.image.repository` / `nginx.image.digest` | data-plane image, by digest | clear the digest to fall back to the upstream F5 image |
| `nginx.kind` | `deployment` | or `daemonSet`; one workload per Gateway |
| `nginx.replicas` | `1` | per provisioned Deployment |
| `nginx.service.type` | `LoadBalancer` | the Service NGF creates in front of each Gateway |
| `nginx.config` | `{}` | extra `NginxProxy` spec, merged under the chart's `kubernetes:` block |
| `controllerName` | `gateway.nginx.org/nginx-gateway-controller` | must match the GatewayClass exactly |
| `gatewayClass.create` / `.name` | `true` / `nginx` | cluster-scoped, so the name is global |
| `watchNamespaces` | `[]` | empty = all namespaces |
| `logLevel` | `info` | written into `NginxGateway`, re-read without a restart |
| `clusterDomain` | `cluster.local` | certificate SANs and the address the agent dials |
| `metrics.enabled` / `.port` / `.secure` | `true` / `9113` / `false` | control-plane metrics |
| `healthPort` | `8081` | `/readyz`, pod-local |
| `leaderElection.enabled` | `true` | extra replicas are warm standbys |
| `productTelemetry.enabled` | `false` | the image has no telemetry endpoint compiled in either |
| `snippetsFilters.enabled` / `snippets.enabled` | `false` | raw nginx directives; enables the matching CRD watches |
| `gatewayApiExperimentalFeatures.enabled` | `false` | needs the experimental-channel Gateway API CRDs |
| `certGenerator.enabled` / `.overwrite` | `true` / `false` | see [Certificates](#certificates) |
| `replicaCount` | `1` | control-plane replicas |
| `service.type` / `.port` | `ClusterIP` / `443` | the agent gRPC endpoint; the port is effectively fixed |
| `rbac.create` | `true` | one ClusterRole, plus a Role for leader election |
| `networkPolicy.enabled` | `true` | allows `agent-grpc` from anywhere by default |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` |

Plus the usual quench-common knobs: `podLabels`, `podAnnotations`, `nodeSelector`,
`affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`,
`extraEnvVars`, `extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the probe
overrides.

## Architecture

```
   GatewayClass ──parametersRef──> NginxProxy  (this chart)
        │                              │
        │ controllerName               │ data-plane image, kind, replicas, Service type
        ▼                              ▼
  ┌───────────────────────┐     per Gateway, in the GATEWAY's namespace
  │  control plane pod    │     ┌──────────────────────────────────────┐
  │  gateway controller   │     │  init: gateway initialize            │
  │  :8443 agent-grpc  ◄──┼─────┤  nginx  ──── njs module              │
  │  :8081 /readyz        │ mTLS│  nginx-agent ── writes /etc/nginx/*  │
  │  :9113 metrics        │ +SA │                                      │
  └───────────────────────┘token└──────────────────────────────────────┘
```

Three consequences worth knowing before operating this:

**The nginx pods are not in this chart's manifests.** `helm get manifest` shows no
nginx workload, and `helm uninstall` removes the control plane while the controller's
finalizers clean up the data planes. Debugging a data plane means looking at the
`NginxProxy` and the controller log, not at chart templates.

**Config reaches nginx over gRPC, not through a ConfigMap.** nginx-agent v3 runs beside
nginx in the same container, receives the generated files and reloads. This is why the
data plane cannot be the general-purpose `quench/nginx` image: it has no agent, and no
njs module for the `load_module` line NGF's own `nginx.conf` opens with.

**The control-plane image is also the data plane's init container.** The controller
reads `IMAGE_NAME` from its own pod spec and reuses it verbatim, so the two are pinned
together by construction — and the image runs as uid 101 / gid 1001, not the usual
1001, because the provisioner hardcodes that uid for the container it creates.

### What this chart deliberately does not install

* **The Gateway API CRDs** — owned by the `gateway-api-crds` chart.
* **`ngx_otel_module`** — tracing. `ObservabilityPolicy` and
  `nginx.config.telemetry.exporter` need a data-plane module that the QuenchWorks image
  does not build (it would drag gRPC/protobuf C++ into a 0-CVE image for one optional
  feature). `values.schema.json` rejects `telemetry.exporter` rather than letting NGF
  emit a `load_module` line for a module that is not there, which would fail the next
  nginx reload. Prometheus metrics are a separate path (agent-collected) and work.
* **NGINX Plus and NGINX App Protect WAF** — Plus is a paid product with its own images.
  The `WAFPolicy` CRD is still installed, because the controller watches the type
  unconditionally and a missing CRD is a cache-sync error rather than a skipped feature.
* **Per-namespace Roles.** Upstream narrows RBAC to Roles in each watched namespace when
  `watchNamespaces` is set. This chart keeps one ClusterRole either way — NGF creates
  the nginx workload in the *Gateway's* namespace, so the write surface has to reach
  wherever a Gateway may appear. Set `rbac.create: false` and bind your own roles to
  `serviceAccount.name` for a tighter install.
* **An admission webhook.** NGF validates through CEL rules in its CRDs.

## Gateway API version skew

NGF 2.6.7 is built against Gateway API **v1.5.x**; the `gateway-api-crds` chart
currently ships **v1.6.1**. NGF reads the CRDs' `bundle-version` annotation and grades
the result:

| skew | GatewayClass conditions |
| --- | --- |
| exact minor | `Accepted=True`, `SupportedVersion=True` |
| minor differs | `Accepted=True`, `SupportedVersion=False` — best effort, which is what you get today |
| major differs | `Accepted=False` — unusable |

So a `SupportedVersion=False` condition on an otherwise healthy install is expected, not
a misconfiguration.

## CRDs

The eleven `gateway.nginx.org` CRDs ship in `crds/`, vendored byte for byte from the
upstream v2.6.7 chart: `NginxProxy`, `NginxGateway`, `ClientSettingsPolicy`,
`ObservabilityPolicy`, `UpstreamSettingsPolicy`, `ProxySettingsPolicy`,
`RateLimitPolicy`, `AuthenticationFilter`, `SnippetsFilter`, `SnippetsPolicy`,
`WAFPolicy`.

They are in `crds/` rather than `templates/` for a measured reason. The bundle is
**909,971 bytes** of source, and Helm stores each release in a Secret capped at
**1,048,576 bytes**. Measured on a real install from `crds/`:

```
sh.helm.release.v1.rtest.v1 stored=405564 bytes
```

Rendering the same CRDs through `templates/` puts them in the manifest as well, on top
of that — the wall the `envoy-gateway` chart walked into with its larger bundle
(1,026,136 of 1,048,576 bytes). Measure again if the bundle grows.

Helm installs `crds/` once and never upgrades them. After a chart upgrade that moves
`appVersion`, re-apply them **server-side**:

```sh
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/quenchworks/charts/main/quench/nginx-gateway-fabric/crds/nginx-gateway-fabric.crds.yaml
```

`--server-side` is not optional here: the `NginxProxy` CRD alone is 664,168 bytes, well
past the 262,144-byte limit on the `kubectl.kubernetes.io/last-applied-configuration`
annotation a client-side apply writes, so `kubectl apply -f` is rejected outright.

## Certificates

The control plane and each nginx-agent authenticate each other with mTLS **plus** a
projected ServiceAccount token whose audience is the control-plane Service name. A
pre-install/pre-upgrade Job runs `gateway generate-certs` and writes:

| Secret | mounted by |
| --- | --- |
| `certGenerator.serverTLSSecretName` (`server-tls`) | the control plane, at `/var/run/secrets/ngf` |
| `certGenerator.agentTLSSecretName` (`agent-tls`) | every provisioned nginx pod |

`certGenerator.overwrite` defaults to **false**, and leaving it that way matters:

* With `overwrite`, every `helm upgrade` mints a **new CA**. The nginx pods already
  running still hold the old material, so their gRPC stream fails verification — the
  data plane keeps serving its last good config while new routes silently never arrive,
  until every nginx pod is restarted.
* Without it, the Job is a no-op on existing Secrets, which is also what makes
  bring-your-own-PKI work: pre-create both Secrets from one CA and the Job leaves them
  alone.

The Secrets are created but not owned by the release, so `helm uninstall` leaves them
behind rather than cutting the config channel of nginx pods that are still serving.

## Configuration examples

Pin nginx to a DaemonSet with two replicas' worth of tuning and access logging off:

```yaml
nginx:
  kind: daemonSet
  service:
    type: NodePort
  config:
    logging:
      agentLevel: info
      errorLevel: warn
    disableHTTP2: false
```

Watch two namespaces only, with a debug control plane:

```yaml
watchNamespaces: [team-a, team-b]
logLevel: debug
```

Bring your own PKI:

```yaml
certGenerator:
  enabled: false
  serverTLSSecretName: ngf-server-tls
  agentTLSSecretName: ngf-agent-tls
```

## Smoke test

`helm install --wait` returning 0 proves the control plane is Ready, which proves
nothing about whether it reconciles. This is what the release gate asserts:

```sh
# 1. the controller accepts the GatewayClass that names it
kubectl wait --for=condition=Accepted --timeout=120s gatewayclass/nginx

# 2. a Gateway is provisioned and programmed (NodePort on kind: no LoadBalancer)
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: example }
spec:
  gatewayClassName: nginx
  listeners: [{ name: http, protocol: HTTP, port: 80 }]
EOF
kubectl wait --for=condition=Programmed --timeout=300s gateway/example

# 3. the provisioned pod really runs the digest-pinned QuenchWorks data plane
kubectl get pod -l gateway.nginx.org/gateway=example \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="nginx")].image}'

# 4. a real request is served through nginx
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: hello }
spec:
  parentRefs: [{ name: example }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: echo, port: 80 }]
EOF
kubectl port-forward svc/example-nginx 8080:80 &
curl -fsS http://127.0.0.1:8080/
```

## Uninstall

```sh
helm uninstall ngf
```

The controller's finalizers tear down the nginx workloads it provisioned. The two TLS
Secrets and the CRDs are left in place on purpose — deleting the CRDs would
cascade-delete every `NginxProxy` and policy in the cluster.

## Verify the chart

```sh
cosign verify ghcr.io/quenchworks/charts/nginx-gateway-fabric \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

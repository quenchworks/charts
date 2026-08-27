# Quenchworks kgateway

Hardened [kgateway](https://github.com/kgateway-dev/kgateway), the CNCF Gateway API
control plane that succeeded Gloo Edge, on minimal, nonroot, 0-CVE images built from
source, cosign-signed and pinned by digest.

The control plane is one stateless, leader-elected Deployment. It runs no data plane
itself: it creates the `kgateway` GatewayClass, and for every Gateway that names it,
provisions a Deployment, Service, ServiceAccount and bootstrap ConfigMap of Envoy pods
**in that Gateway's own namespace**, then programs them over xDS.

Two images, both ours:

| | what it is |
|---|---|
| `kgateway` | the controller. Also carries the Wolfi Envoy binary at `/usr/local/bin/envoy`, which is the path kgateway forks for `envoy --mode validate` under `validation.level: strict`. |
| `kgateway-envoy` | the data plane — upstream's `envoy-wrapper`, rebuilt clean-room: the QuenchWorks hardened Envoy binary plus kgateway's own `envoyinit` shim. |

`kgateway-envoy` exists rather than reusing the plain quench [`envoy`](../envoy) chart's
image because the proxy container kgateway generates carries **args only, no command and
no `-c`**. The image entrypoint has to find `/etc/envoy/envoy.yaml` itself, expand the
Kubernetes Downward API templates the controller wrote into it, append the OS CA bundle
as the `system_trust` static secret, and then exec Envoy. That is what `envoyinit` does.
The Envoy binary it execs is the same Wolfi apk that backs the `envoy` image.

## Install

The Gateway API CRDs are **not** part of this chart, and nothing works without them.
They are cluster-scoped singletons owned by the
[`gateway-api-crds`](../gateway-api-crds) chart, whose appVersion 1.6.1 is exactly the
Gateway API version kgateway 2.4.3 is conformant against:

```bash
helm install gateway-api-crds oci://ghcr.io/quenchworks/charts/gateway-api-crds
helm install kgateway oci://ghcr.io/quenchworks/charts/kgateway
```

kgateway's own eight `gateway.kgateway.dev` CRDs **do** ship here, in `crds/`. See
[CRDs](#crds) for what that means on upgrade.

The controller creates its own GatewayClass, so there is nothing to claim — just create
a Gateway:

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example
spec:
  gatewayClassName: kgateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gatewayclass kgateway -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'
kubectl get gateway example -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
```

`Accepted=True` on the GatewayClass is the signal that the controller is really
reconciling; a Ready pod is not. `Programmed=True` on the Gateway additionally means the
Envoy fleet exists and has an address — on a cluster with no LoadBalancer
implementation it stays `False` until you switch the provisioned Service to `ClusterIP`
or `NodePort`, see [Configuration examples](#configuration-examples).

## Verify the images

```bash
for i in kgateway kgateway-envoy; do
  cosign verify "ghcr.io/quenchworks/images/$i" \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/kgateway --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/kgateway` | The controller. |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `dataPlane.image.repository` | `ghcr.io/quenchworks/images/kgateway-envoy` | The proxy pods. Version-locked to the controller. |
| `dataPlane.image.digest` | (CI-written) | Required. |
| `dataPlane.gatewayParameters.create` | `true` | Create the GatewayParameters that pins the proxy image and wire the managed classes to it. |
| `dataPlane.gatewayParameters.name` | `""` | Defaults to the release fullname. |
| `dataPlane.gatewayParameters.gatewayClasses` | `[kgateway, kgateway-waypoint]` | The two classes kgateway manages. `kgateway-waypoint` is skipped unless `waypoint.enabled`. |
| `dataPlane.logLevel` | `info` | Envoy log level in the provisioned pods. |
| `replicaCount` | `1` | Stateless and leader-elected: extra replicas are warm standbys. |
| `logLevel` | `info` | `debug` / `info` / `warn` / `error`. |
| `defaultImageRegistry` | `ghcr.io/quenchworks/images` | Registry the controller composes compiled-in image names against. Deliberately ours, see [Data plane](#data-plane). |
| `adminBindAddress` | `localhost` | Admin/debug server on 9095 (pprof, log level, config dumps). |
| `validation.level` | `standard` | `strict` additionally forks `envoy --mode validate` per translation. See [Validation](#validation). |
| `waypoint.enabled` | `false` | Istio ambient waypoint support. See [What this chart deliberately does not install](#what-this-chart-deliberately-does-not-install). |
| `discoveryNamespaceSelectors` | `[]` | Namespace selectors (OR'ed) limiting config discovery. Empty means all namespaces. |
| `policyMerge` | `{}` | Deep-merge behaviour for TrafficPolicy `extAuth` / `extProc` / `transformation`. |
| `enableRouteSourceMetadata` | `false` | Attach `dev.kgateway.route_source` metadata to every generated route. Experimental upstream. |
| `xds.tls.enabled` | `false` | TLS on the xDS gRPC server. Needs a `kubernetes.io/tls` Secret named `kgateway-xds-cert` — that name is fixed in the controller, not by this chart. |
| `service.type` | `ClusterIP` | |
| `service.xdsPort` | `9977` | Written into every generated proxy bootstrap; the fleet dials this Service by name. |
| `service.metricsPort` | `9092` | Prometheus. |
| `service.healthPort` | `9093` | controller-runtime `/healthz` and `/readyz`. |
| `resources` | 100m/256Mi → 1/1Gi | `GOMEMLIMIT` and `GOMAXPROCS` are derived from the limits. |
| `serviceAccount.create` | `true` | |
| `rbac.create` | `true` | Cluster-scoped by necessity, see [RBAC](#rbac). |
| `networkPolicy.enabled` | `true` | Ingress to xDS/metrics/health allowed cluster-wide by default: the fleet dials from any namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the usual quench-common knobs: `podLabels`, `podAnnotations`, `nodeSelector`,
`affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`,
`schedulerName`, `terminationGracePeriodSeconds`, `updateStrategy`, `extraEnvVars`,
`extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`, `extraVolumeMounts`,
`initContainers`, `sidecars`, `lifecycleHooks`, `podSecurityContext`,
`containerSecurityContext` and the probe overrides.

## Architecture

```
                    ┌──────────────────────────────────────┐
   Gateway API  ───▶ │  kgateway controller (this chart)   │
   HTTPRoute        │  Deployment, 1 replica, leader-elect │
   TrafficPolicy    │  xDS 9977 · metrics 9092 · health 9093│
   Backend  ...     └──────────────┬───────────────────────┘
                                   │ creates + programs
                    ┌──────────────▼───────────────────────┐
                    │ per Gateway, in the GATEWAY's ns:    │
                    │  Deployment of kgateway-envoy pods   │
                    │  Service, ServiceAccount, ConfigMap  │
                    └──────────────────────────────────────┘
```

The controller is configured entirely through `KGW_*` environment variables — there is
no config file and no `ConfigMap` in this chart. The image entrypoint is the bare
`kgateway` binary with no subcommand.

### Data plane

kgateway reads the proxy image from a **GatewayParameters** resource, not from this
chart's pod spec. It starts from a GatewayParameters it builds in code, whose
`envoyContainer.image` defaults to `<KGW_DEFAULT_IMAGE_REGISTRY>/envoy-wrapper:<tag>`,
and merges the GatewayClass's `parametersRef` over it field by field. So the chart
creates one GatewayParameters pinning our image by digest and attaches it to the managed
classes with `KGW_GATEWAY_CLASS_PARAMETERS_REFS`.

Two consequences worth knowing:

* `KGW_DEFAULT_IMAGE_REGISTRY` is set to **our** registry rather than left at
  `cr.kgateway.dev`. Any code path the GatewayParameters does not cover then fails to
  pull loudly, instead of quietly running somebody else's proxy binary next to our
  control plane.
* An extra GatewayClass of your own with `controllerName: kgateway.dev/kgateway` will
  **not** inherit it — kgateway only manages the two classes it creates. Point that
  class's `spec.parametersRef` at the same GatewayParameters
  (`group: gateway.kgateway.dev`, `kind: GatewayParameters`).

### Validation

`validation.level: standard` (the default) rewrites an invalid route to a direct 500 and
carries on. `strict` additionally forks `envoy --mode validate` for each translation and
refuses to publish a snapshot Envoy would NACK; the controller image carries the Envoy
binary at the hard-coded `/usr/local/bin/envoy` for exactly that, and the root
filesystem is read-only with a `/tmp` emptyDir so the fork has somewhere to write.

Strict validation of a TrafficPolicy that uses `transformation` or `rbac` will **fail**,
because those emit an Envoy dynamic-module filter this image cannot load — see below.

### RBAC

Cluster-scoped, by necessity rather than by default: kgateway provisions each Envoy
fleet into its Gateway's own namespace, so the Deployment/Service/ServiceAccount/
ConfigMap writes cannot live in a namespaced Role. It also **creates** GatewayClasses,
which is why `create` is granted there. Narrow the reach with
`discoveryNamespaceSelectors`, or set `rbac.create=false` and bind your own ClusterRole
to `serviceAccount.name`.

### What this chart deliberately does not install

* **The Gateway API CRDs.** Cluster-scoped singletons owned by the
  [`gateway-api-crds`](../gateway-api-crds) chart. Install that first.
* **`librust_module.so`**, the Envoy Rust dynamic module upstream bundles into both of
  its images. TrafficPolicy `transformation` and `rbac` translate to an
  `envoy.extensions.filters.http.dynamic_modules.v3.DynamicModuleFilter` naming
  `rust_module`, and Envoy rejects that config without the module on disk. Everything
  else — HTTPRoute/GRPCRoute/TCPRoute/TLSRoute routing, ListenerPolicy,
  HTTPListenerPolicy, BackendConfigPolicy, Backend, DirectResponse, and TrafficPolicy's
  ext-auth, ext-proc, rate limiting, CORS, CSRF, retry and timeout sections — needs no
  dynamic module.

  Why it is not shipped: the module's `rust-toolchain.toml` pins Rust channel **1.95.0**
  while Wolfi's newest is `rust-1.92`, and its SDK
  (`envoy-proxy-dynamic-modules-rust-sdk`) is a **git dependency on the envoyproxy/envoy
  repository at the exact Envoy patch tag** — `v1.38.3` for kgateway 2.4.3 — because the
  dynamic-module ABI is version-checked against the Envoy binary at load time. Our
  Envoy is Wolfi's `envoy-1.38` apk at 1.38.1, the newest in that line, so even a
  successful build would be loading a module compiled against a different patch.
  Shipping it would mean either vendoring a Rust toolchain Wolfi does not carry or
  pretending an ABI match we cannot demonstrate. Revisit when Wolfi carries Rust 1.95
  and `envoy-1.38` reaches 1.38.3.
* **The `sds` image**, kgateway's third binary. It is the cert sidecar for the
  Istio-ambient auto-mTLS path only, so `waypoint.enabled: true` gives you waypoint
  translation but not that sidecar.
* **ServiceMonitor / HPA / VPA.** The controller is leader-elected: horizontal scaling
  buys warm standbys, not throughput. Prometheus pod-annotation discovery is on by
  default via `podAnnotations`; add a ServiceMonitor of your own against the `metrics`
  port if you run the Prometheus Operator.

## Envoy coupling

kgateway generates its xDS against a specific Envoy minor, and Wolfi packages Envoy by
minor. The pairing is not something to guess at on an upgrade:

| kgateway | upstream `ENVOY_IMAGE` | our `envoy` apk |
|---|---|---|
| 2.3.7 | `envoyproxy/envoy:v1.37.5` | `envoy-1.37` = 1.37.1 |
| 2.4.3 | `envoyproxy/envoy:v1.38.3` | `envoy-1.38` = 1.38.1 |

Within one minor the xDS API and bootstrap schema are stable, which is what the control
plane depends on; the patch gap is a Wolfi packaging lag. `scripts/check/kgateway.py` in
the images repo reads the candidate tag's own Makefile on every update check and says
whether we ship that minor at all.

kgateway **2.2.x is not shipped**: it pins its amd64 data plane to
`quay.io/solo-io/envoy-gloo:1.36.9-patch1`, a vendor fork of Envoy carrying the C++
transformation filters, which this catalog neither ships nor rebuilds. 2.3.0 moved the
project to stock upstream Envoy plus the Rust dynamic module, which is what makes 2.3+
runnable on our own Envoy.

## CRDs

The eight `gateway.kgateway.dev` CRDs ship in `crds/`, not `templates/`, and that has
consequences Helm users should know:

* `helm install` and `helm upgrade` **create** them but never **update** them. Apply the
  new bundle by hand on an appVersion bump:
  `kubectl apply --server-side -f crds/kgateway.crds.yaml`.
* `helm uninstall` does **not** delete them, which is the safe default — deleting a CRD
  deletes every object of that kind.

They are in `crds/` for three reasons that were all measured on a kind cluster, not
assumed:

1. **Helm installs `crds/` before it renders `templates/`.** This chart's own
   GatewayParameters is a `gateway.kgateway.dev` object. With the CRDs as templates the
   install fails outright: `no matches for kind "GatewayParameters" in version
   "gateway.kgateway.dev/v1alpha1"`.
2. **The TrafficPolicy CRD's transformation docs contain Helm-escaped template tokens.**
   As a template the render fails with `function "route_name" not defined`; vendored into
   `crds/` the tokens are unescaped back to the literals the docs mean.
3. **Size.** The bundle is 1.6 MiB of source and Helm stores the release in a Secret
   capped at 1,048,576 bytes. From `crds/` the release Secret is 545,332 decoded bytes
   (52.0% of the cap); templated it is 823,220 (78.5%) — which fits today, but leaves
   little headroom for a bundle that grows with every release.

Note that a plain client-side `kubectl apply -f crds/kgateway.crds.yaml` **fails**, and
not because the file is wrong: the GatewayParameters CRD alone is 520 KiB, and
`kubectl apply` stores a copy of it in the `last-applied-configuration` annotation, which
the API server caps at 262,144 bytes. Use `--server-side`, as above.

## Configuration examples

A ClusterIP Gateway, for a cluster with no LoadBalancer (kind, k3d):

```yaml
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayParameters
metadata:
  name: clusterip
spec:
  kube:
    service:
      type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example
spec:
  gatewayClassName: kgateway
  infrastructure:
    parametersRef:
      group: gateway.kgateway.dev
      kind: GatewayParameters
      name: clusterip
  listeners:
    - name: http
      protocol: HTTP
      port: 80
```

A per-Gateway GatewayParameters merges over the chart's, so the digest-pinned image is
inherited and does not need repeating.

Restrict discovery to labelled namespaces:

```yaml
discoveryNamespaceSelectors:
  - matchLabels:
      kgateway: enabled
```

Scale the proxy fleet and give it resources, without touching the control plane:

```yaml
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayParameters
metadata:
  name: production
spec:
  kube:
    deployment:
      replicas: 3
    envoyContainer:
      resources:
        requests: { cpu: 500m, memory: 512Mi }
        limits: { cpu: "2", memory: 2Gi }
```

## Smoke test

```bash
# 1. the controller creates and accepts its own GatewayClass
kubectl wait --for=condition=Accepted --timeout=120s gatewayclass/kgateway

# 2. it provisions and programs a Gateway (ClusterIP, so this works on kind)
kubectl apply -f - <<'EOF'
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayParameters
metadata: { name: clusterip }
spec:
  kube:
    service: { type: ClusterIP }
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: example }
spec:
  gatewayClassName: kgateway
  infrastructure:
    parametersRef: { group: gateway.kgateway.dev, kind: GatewayParameters, name: clusterip }
  listeners: [{ name: http, protocol: HTTP, port: 80 }]
EOF
kubectl wait --for=condition=Programmed --timeout=300s gateway/example

# 3. the fleet runs OUR data-plane image
kubectl get pod -l gateway.networking.k8s.io/gateway-name=example \
  -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'

# 4. the fleet serves a route it was given over xDS. A DirectResponse needs no
#    backend image and exercises this chart's own CRD end to end.
kubectl apply -f - <<'EOF'
apiVersion: gateway.kgateway.dev/v1alpha1
kind: DirectResponse
metadata: { name: hello }
spec:
  status: 200
  body: "quenchworks-kgateway-ok"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: hello }
spec:
  parentRefs: [{ name: example }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      filters:
        - type: ExtensionRef
          extensionRef: { group: gateway.kgateway.dev, kind: DirectResponse, name: hello }
EOF
kubectl port-forward svc/example 8080:80 &
curl -fsS http://127.0.0.1:8080/
# quenchworks-kgateway-ok
```

## Uninstall

```bash
helm uninstall kgateway
```

Gateways and routes are not owned by the release, so delete them first if you want the
proxy fleets gone; the CRDs in `crds/` survive on purpose. Removing them, and every
object of those kinds:

```bash
kubectl delete -f crds/kgateway.crds.yaml
```

## Verify the chart

```bash
cosign verify ghcr.io/quenchworks/charts/kgateway \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

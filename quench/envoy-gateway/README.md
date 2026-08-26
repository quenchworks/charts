# Quenchworks Envoy Gateway

Hardened [Envoy Gateway](https://github.com/envoyproxy/gateway), the CNCF Gateway
API control plane that turns GatewayClass, Gateway and route objects into fleets
of running Envoy proxies, on a minimal, nonroot, 0-CVE image built from source,
cosign-signed and pinned by digest.

The control plane is one stateless Deployment running
`envoy-gateway server --config-path=/config/envoy-gateway.yaml`. It runs no data
plane itself: for every Gateway that names its GatewayClass it creates a
Deployment, Service, ServiceAccount and bootstrap ConfigMap of Envoy pods in the
control plane's own namespace, and configures them over xDS.

## Install

The Gateway API CRDs are **not** part of this chart, and nothing works without
them. They are cluster-scoped singletons owned by the
[`gateway-api-crds`](../gateway-api-crds) chart:

```bash
helm install gateway-api-crds oci://ghcr.io/quenchworks/charts/gateway-api-crds
helm install eg oci://ghcr.io/quenchworks/charts/envoy-gateway
```

Envoy Gateway's own eight `gateway.envoyproxy.io` CRDs **do** ship here, in
`crds/`. See [CRDs](#crds) for what that means on upgrade.

Then claim a GatewayClass and create a Gateway:

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'
kubectl get gateway example -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
```

`Accepted=True` on the GatewayClass is the signal that the controller is really
reconciling; a Ready pod is not. `Programmed=True` on the Gateway additionally
means the Envoy fleet exists and has an address — on a cluster with no
LoadBalancer implementation it stays `False` with `AddressNotAssigned` until you
switch the provisioned Service to `ClusterIP` or `NodePort`, see
[Configuration examples](#configuration-examples).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/envoy-gateway \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with
`gh attestation verify oci://ghcr.io/quenchworks/images/envoy-gateway --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/envoy-gateway` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `envoyProxy.image.repository` | `ghcr.io/quenchworks/images/envoy` | Image for the Envoy pods the controller provisions. |
| `envoyProxy.image.digest` | (CI-written) | Set to `""` to use the upstream image compiled into Envoy Gateway. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Leader-elected: extra replicas are warm standbys. |
| `controllerName` | `gateway.envoyproxy.io/gatewayclass-controller` | A GatewayClass is reconciled only on an exact match. |
| `logLevel` | `info` | `debug`, `info`, `warn`, `error`. |
| `kubernetesClusterDomain` | `cluster.local` | Used for the xDS server name and the certificate SANs. |
| `config` | `{}` | Extra [EnvoyGateway](https://gateway.envoyproxy.io/docs/api/extension_types/#envoygateway) spec fields, deep-merged over the chart's. |
| `certgen.enabled` | `true` | Pre-install/pre-upgrade `envoy-gateway certgen` Job. |
| `certgen.secretName` | `envoy-gateway` | Holds the xDS CA and certificates. Fixed upstream. |
| `certgen.ttlSecondsAfterFinished` | `30` | |
| `certgen.resources` | `cpu 50m-500m / mem 64Mi-256Mi` | |
| `resources.requests` | `cpu 100m / mem 256Mi` | |
| `resources.limits` | `cpu 1 / mem 1Gi` | |
| `service.type` | `ClusterIP` | The control plane's own Service, not a Gateway's. |
| `service.annotations` | `{}` | |
| `service.xdsPort` | `18000` | xDS to the Envoy fleet. |
| `service.ratelimitPort` | `18001` | xDS to the optional ratelimit deployment. |
| `service.wasmPort` | `18002` | Wasm module cache the Envoy pods fetch from. |
| `service.metricsPort` | `19001` | Prometheus metrics. |
| `wasmCacheVolume` | `{emptyDir: {}}` | Backs `/var/lib/eg/wasm`; the root filesystem is read-only. |
| `serviceAccount.create` | `true` | |
| `serviceAccount.automountServiceAccountToken` | `true` | The controller is an API-server client and needs its token. |
| `rbac.create` | `true` | ClusterRole (watch) + Role (provision, lead). |
| `networkPolicy.enabled` | `true` | |
| `networkPolicy.allowExternal` | `true` | The Envoy fleet dials xDS from its Gateway's namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

```
              ┌──────────── control plane (this chart) ────────────┐
GatewayClass  │  Deployment  envoy-gateway server                  │
Gateway    ──►│    /config/envoy-gateway.yaml  (ConfigMap)         │
HTTPRoute     │    /certs                      (Secret, certgen)   │
EnvoyProxy    │    /var/lib/eg/wasm            (emptyDir)          │
              │  Service  envoy-gateway  18000/18001/18002/19001   │
              └───────────────────────┬───────────────────────────-┘
                                      │ xDS over mTLS
              ┌───────────────────────▼───────────────────────────┐
              │  data plane, created BY the controller per Gateway │
              │    Deployment envoy-<ns>-<gw>   envoy + shutdown-  │
              │    Service    envoy-<ns>-<gw>   manager sidecar    │
              └───────────────────────────────────────────────────┘
```

Three details are worth knowing because they are not free choices:

**The Service is named `envoy-gateway`, not `<release>-envoy-gateway`.**
`envoy-gateway certgen` issues the control-plane certificate for the SANs
`envoy-gateway[.<namespace>[.svc[.<domain>]]]`, and every provisioned Envoy pod
dials `envoy-gateway.<namespace>.svc.<domain>:18000` for xDS and verifies that
name. A release-prefixed Service would leave the whole fleet unable to connect.
The consequence is that only one Envoy Gateway control plane can live in a
namespace; put a second one in a namespace of its own and give it a distinct
`controllerName`.

**One image, two roles.** The control plane runs `envoy-gateway server`, and the
controller injects the *same* image into every Envoy pod as a `shutdown-manager`
sidecar with a different argv (`envoy shutdown-manager`), which drains
connections on pod termination. That is why the image entrypoint is the bare
binary with no baked-in subcommand, and why this chart passes `server` itself.
The chart writes its own digest into
`provider.kubernetes.shutdownManager.image`, so the sidecar is pinned too.

**The data-plane image comes from config, not from a pod spec.** Envoy Gateway
builds the Envoy Deployment itself, reading the image from the EnvoyGateway
config file. The chart writes the QuenchWorks Envoy image there, so a default
install runs a 0-CVE data plane. Clear `envoyProxy.image.digest` to fall back to
the upstream image compiled into Envoy Gateway.

That default applies only while the GatewayClass has no `parametersRef`. A
GatewayClass that points at an EnvoyProxy resource **replaces** the chart's
`envoyProxy` config wholesale rather than merging with it, so such a fleet
silently reverts to the upstream Envoy image unless the EnvoyProxy repeats the
image itself:

```yaml
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        container:
          image: ghcr.io/quenchworks/images/envoy@sha256:...
```

### What this chart deliberately does not install

The **proxy topology injector** is off. It is an optional scheduling optimisation
that co-locates Envoy pods with their backends, implemented as a cluster-wide
`MutatingWebhookConfiguration` on pod creation. Leaving it off keeps the install
to one Deployment, one Service and one Job, and puts no admission webhook in the
path of every pod creation in the cluster. `proxyTopologyInjector.disabled: true`
is written into the config and `certgen` is run with
`--disable-topology-injector`; do not re-enable it through `.Values.config`
alone, because the webhook it would point the API server at does not exist.

The **global rate limit service** is not deployed either. Rate limiting needs a
separate `envoyproxy/ratelimit` deployment and a Redis, neither of which is in
this catalogue yet. Local (per-pod) rate limiting via BackendTrafficPolicy needs
nothing extra and works today.

## CRDs

`crds/envoy-gateway.crds.yaml` holds Envoy Gateway's own eight CRDs, vendored
byte for byte from the upstream `gateway-crds-helm` chart at v1.9.0: Backend,
BackendTrafficPolicy, ClientTrafficPolicy, EnvoyExtensionPolicy,
EnvoyPatchPolicy, EnvoyProxy, HTTPRouteFilter, SecurityPolicy.

They are in `crds/` rather than `templates/`, unlike the sibling
`gateway-api-crds` chart, for one measured reason. The bundle is 2.5 MiB of
YAML. Helm keeps each release in a single Secret holding both the chart files and
the rendered manifest, and Kubernetes caps a Secret at 1 MiB:

| Placement | Stored release Secret |
|-----------|----------------------|
| `templates/` (chart file **and** rendered manifest) | ~1.10 MiB — install refused |
| `crds/` (chart file only) | 1002 KiB — installs |

That is 2% of headroom, not a comfortable margin. If a future Envoy Gateway
release grows these schemas, the fix is to split them into their own chart the
way the Gateway API CRDs already are, not to shrink them.

Helm installs `crds/` once and never upgrades it. A chart upgrade that moves
`appVersion` therefore leaves the old schemas in place; re-apply them yourself:

```bash
kubectl apply --server-side \
  -f https://raw.githubusercontent.com/quenchworks/charts/main/quench/envoy-gateway/crds/envoy-gateway.crds.yaml
```

`helm install --skip-crds` suppresses them entirely, for clusters where CRDs are
managed by a separate pipeline.

## Certificates

A `pre-install,pre-upgrade` hook Job runs `envoy-gateway certgen`, which mints a
CA, the control-plane serving certificate and the Envoy client certificate into
the `envoy-gateway` Secret. The controller mounts it at `/certs` and will not
serve xDS without it.

certgen never overwrites an existing Secret. That is the supported way to bring
your own PKI: pre-create the Secret with `ca.crt`, `tls.crt` and `tls.key` for
the SANs above — with cert-manager, for instance — and certgen leaves it alone.

The Secret is created by the Job, so it is not owned by the release and
`helm uninstall` leaves it behind. That is intentional: deleting it would
invalidate the certificates of every Envoy pod still running.

## Configuration examples

Provision Envoy fleets behind a ClusterIP instead of a LoadBalancer — the usual
need on kind, and what makes a Gateway reach `Programmed=True` there:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: clusterip
  namespace: envoy-gateway
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: ClusterIP
      # Repeated because a parametersRef replaces the chart's default config.
      envoyDeployment:
        container:
          image: ghcr.io/quenchworks/images/envoy@sha256:99cf0132c2d9521d564329f78512f5ba521d8e147a824bf64f3c27352efbc0af
```

referenced from the GatewayClass:

```yaml
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: clusterip
    namespace: envoy-gateway
```

Watch only some namespaces (the RBAC this chart installs is cluster-wide read;
narrowing the watch does not narrow the ClusterRole, bind your own if you need
that):

```yaml
config:
  provider:
    kubernetes:
      watch:
        type: Namespaces
        namespaces: [team-a, team-b]
```

Run a second, independent control plane in another namespace:

```yaml
controllerName: gateway.envoyproxy.io/team-b-controller
```

Keep the Wasm module cache across restarts:

```yaml
wasmCacheVolume:
  persistentVolumeClaim:
    claimName: envoy-gateway-wasm-cache
```

## Smoke test

A Ready pod proves nothing. These three steps prove the controller reconciles,
provisions, and that the data plane serves traffic it was configured with over
xDS:

```bash
# 1. the controller accepts a GatewayClass that names it
kubectl get gatewayclass eg \
  -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'   # True

# 2. it provisions and programs a Gateway
kubectl get gateway example \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' # True

# 3. the Envoy fleet serves a route (no backend needed: a direct response
#    exercises this chart's own HTTPRouteFilter CRD end to end)
kubectl apply -f - <<'EOF'
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: HTTPRouteFilter
metadata: { name: hello }
spec:
  directResponse:
    contentType: text/plain
    statusCode: 200
    body: { type: Inline, inline: "ok" }
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
          extensionRef: { group: gateway.envoyproxy.io, kind: HTTPRouteFilter, name: hello }
EOF

kubectl port-forward svc/$(kubectl get svc -l gateway.envoyproxy.io/owning-gateway-name=example -o name | cut -d/ -f2) 8080:80 &
curl -s http://127.0.0.1:8080/    # ok
```

## Uninstall

```bash
helm uninstall eg
```

Left behind on purpose: the `envoy-gateway` Secret (see
[Certificates](#certificates)) and everything in `crds/`, because deleting a CRD
cascade-deletes every object of that kind. Delete your Gateways first if you want
their Envoy fleets torn down cleanly — the controller garbage-collects them, and
it cannot do that once it is gone.

## Verify the chart

```bash
cosign verify ghcr.io/quenchworks/charts/envoy-gateway \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

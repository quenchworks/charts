# Quenchworks Apache APISIX Ingress Controller

Hardened [Apache APISIX Ingress Controller](https://github.com/apache/apisix-ingress-controller),
the Kubernetes control plane that turns `apisix.apache.org` custom resources,
native Ingress and Gateway API objects into APISIX configuration, on minimal,
nonroot, 0-CVE images built from source, cosign-signed and pinned by digest.

It runs no data plane. It watches Kubernetes, translates what it finds into a
declarative document, and pushes that into an APISIX Admin API — the
[`apisix`](../apisix) chart, or any APISIX you already run.

## The pod has two containers, and that is not optional

The controller does not speak to APISIX itself. It hands every sync to
[`adc`](https://github.com/api7/adc) — API Declarative CLI — over a Unix socket,
and `adc` is what calls the Admin API. Upstream's own Deployment is the same
two-container pod, and the controller release pins the sidecar version
(`Makefile ADC_VERSION`), so `image.digest` and `adc.image.digest` move together
or not at all.

A single-container install is not a degraded install. It comes up `1/1 Ready`,
accepts a GatewayClass, and fails every sync — nothing in pod status says so.

```
   ┌─────────────────────── one pod ────────────────────────┐
   │  apisix-ingress-controller          adc-server         │
   │  watches K8s, translates    ──────► calls the Admin API│
   │  ADC_SERVER_URL=unix:/sockets/adc.sock  (emptyDir)     │
   └──────────────────────────────┬─────────────────────────┘
                                  │ HTTP + X-API-KEY
                    ┌─────────────▼──────────────┐
                    │  APISIX data plane :9180   │  ← quench/apisix, or yours
                    └────────────────────────────┘
```

## Install

Two things must exist first.

**The Gateway API CRDs.** Cluster-scoped singletons, owned by the
[`gateway-api-crds`](../gateway-api-crds) chart (1.6.1, the version this
controller release targets). Not bundled here, and required while
`gatewayAPI.enabled` is left on.

**An APISIX data plane with its Admin API reachable.**

```bash
helm install gateway-api-crds oci://ghcr.io/quenchworks/charts/gateway-api-crds
helm install dp oci://ghcr.io/quenchworks/charts/apisix

helm install aic oci://ghcr.io/quenchworks/charts/apisix-ingress-controller \
  --set dataPlane.endpoints[0]=http://dp-apisix:9180 \
  --set dataPlane.adminKey.existingSecret=dp-apisix-admin
```

The twelve `apisix.apache.org` CRDs **do** ship here, in `crds/`. See
[CRDs](#crds) for what that means on upgrade.

Then create a route:

```yaml
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: example
spec:
  ingressClassName: apisix
  http:
    - name: rule
      match:
        paths: ["/get"]
      backends:
        - serviceName: httpbin
          servicePort: 80
```

```bash
kubectl get apisixroute example \
  -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'   # True
```

`Accepted=True` is the signal that matters. It is set only *after* adc's sync to
the Admin API returns success, so that one condition covers translation, RBAC on
the `/status` subresource, the shared adc socket and the Admin API round trip. A
Ready pod covers none of it.

`Accepted=False` with `no matching IngressClass` means the route named a class
this install does not own; the message on the condition says which failure it
was.

## How a route finds APISIX

Nothing is implicit. A route resolves to a data plane through a chain:

```
ApisixRoute.spec.ingressClassName
        │
        ▼
IngressClass   spec.controller == controllerName, spec.parameters ──┐
                                                                    ▼
                                                    GatewayProxy   endpoints + admin key
                                                                    │
                                                                    ▼
                                                        APISIX Admin API :9180
```

`dataPlane.create: true` builds all of it: the GatewayProxy, the IngressClass and
— when `gatewayClass.create` is on — the GatewayClass. Set `dataPlane.create:
false` to manage those three yourself, for instance to drive several data planes
from one controller with one GatewayProxy each.

**A Gateway needs its own `spec.infrastructure.parametersRef`.** The
GatewayClass's `parametersRef` is *not* inherited by Gateways that name the class.
Without it a Gateway sits at `Accepted=False` with `gateway proxy not found`,
while its listener cheerfully reports `Programmed=True`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: example }
spec:
  gatewayClassName: apisix
  infrastructure:
    parametersRef:
      group: apisix.apache.org
      kind: GatewayProxy
      name: aic-apisix-ingress-controller
  listeners:
    - { name: http, protocol: HTTP, port: 80 }
```

## Sync modes

`dataPlane.mode` sets both the GatewayProxy's `controlPlane.mode` and the
controller's `provider.type`, so they cannot disagree.

| Mode | Data plane it drives |
|------|----------------------|
| `apisix` (default) | The classic Admin API of an etcd-backed APISIX — what the [`apisix`](../apisix) chart installs. |
| `apisix-standalone` | The file-driven standalone Admin API (APISIX 3.13+ with `config_provider: yaml`). The controller resolves pod endpoints itself in this mode. |

`mode` is immutable on an existing GatewayProxy (a CEL rule on the CRD), so
switching means deleting and recreating it.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/apisix-ingress-controller \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
cosign verify ghcr.io/quenchworks/images/adc \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with
`gh attestation verify oci://ghcr.io/quenchworks/images/apisix-ingress-controller --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/apisix-ingress-controller` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `adc.image.repository` | `ghcr.io/quenchworks/images/adc` | The required sidecar. |
| `adc.image.digest` | (CI-written) | Required. Pinned to the version this controller release names. |
| `adc.socketPath` | `/sockets/adc.sock` | Shared through an emptyDir; the controller dials it as `ADC_SERVER_URL`. |
| `adc.statusPort` | `3001` | Where adc serves `GET /healthz/ready`. The socket carries `/sync` and `/validate` only. |
| `adc.logLevel` | `info` | |
| `adc.featureFlags` | `remote-state-file,parallel-backend-request` | Upstream's ingress-mode flags. `remote-state-file` is what lets adc run a read-only rootfs. |
| `adc.resources` | 50m/128Mi → 500m/512Mi | |
| `replicaCount` | `1` | Leader-elected; extra replicas are warm standbys, not throughput. |
| `controllerName` | `apisix.apache.org/apisix-ingress-controller` | Matched against `IngressClass.spec.controller` and `GatewayClass.spec.controllerName`. |
| `logLevel` | `info` | `debug`, `info`, `warn`, `error`. |
| `leaderElection.enabled` | `true` | Off drops the Lease Role and the leader-election config. |
| `leaderElection.id` | `apisix-ingress-controller-leader` | Lease name, in the release namespace. |
| `syncPeriod` | `1h` | Upstream's default; effectively event-driven only. Lower it to repair drift faster. |
| `initSyncDelay` | `20m` | Delay before the first full sync after start-up. |
| `execAdcTimeout` | `15s` | Per-sync timeout on the adc call. |
| `gatewayAPI.enabled` | `true` | Off drops the Gateway API watches *and* the Gateway API RBAC. |
| `config` | `{}` | Deep-merged over the rendered `config.yaml`. Full surface: upstream `config/manager/config.yaml`. |
| `dataPlane.create` | `true` | Creates the GatewayProxy + IngressClass (+ GatewayClass). |
| `dataPlane.mode` | `apisix` | See [Sync modes](#sync-modes). Immutable once created. |
| `dataPlane.endpoints` | `[]` | Admin API URLs. Exactly one of this or `dataPlane.service`. |
| `dataPlane.service` | `{}` | `{name, port}` of a Service in this namespace, instead of `endpoints`. |
| `dataPlane.tlsVerify` | `false` | Verify the Admin API certificate. Only relevant for `https` endpoints. |
| `dataPlane.adminKey.existingSecret` | `""` | Preferred. `quench/apisix` generates `<release>-apisix-admin`. |
| `dataPlane.adminKey.existingSecretKey` | `admin-key` | |
| `dataPlane.adminKey.value` | `""` | Inline key. Visible in the GatewayProxy; for throwaway clusters. |
| `dataPlane.pluginMetadata` | `{}` | Global plugin metadata pushed to the data plane, keyed by plugin name. |
| `ingressClass.create` | `true` | |
| `ingressClass.name` | `apisix` | |
| `ingressClass.default` | `false` | Claim routes and Ingresses that name no class at all. |
| `gatewayClass.create` | `false` | Cluster-scoped singleton; opt in. Requires `gatewayAPI.enabled`. |
| `gatewayClass.name` | `apisix` | |
| `resources` | 50m/128Mi → 500m/512Mi | |
| `containerPorts.probe` | `8081` | `/healthz` and `/readyz`. Pod-local, not on the Service. |
| `containerPorts.metrics` | `8080` | |
| `service.type` | `ClusterIP` | Metrics only — this control plane serves no traffic. |
| `service.metricsPort` | `8080` | |
| `serviceAccount.automountServiceAccountToken` | `true` | The controller is an API-server client; it cannot work without its token. |
| `rbac.create` | `true` | See [RBAC](#rbac). |
| `networkPolicy.enabled` | `true` | |
| `networkPolicy.allowExternal` | `false` | Only the metrics port is exposed, so ingress is namespace-local. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` surface: `nameOverride`, `fullnameOverride`,
`commonLabels`, `commonAnnotations`, `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides.

## Hardening notes

Three things in the pod spec look like detail and are load-bearing.

**`POD_NAMESPACE`.** It is the manager's `LeaderElectionNamespace`, and it
defaults to `default`, *not* to the pod's own namespace. Omit it and a release in
any other namespace takes its Lease in `default`, where this chart's namespaced
Role grants nothing: the pod reports Ready and the log fills with
`leases.coordination.k8s.io ... is forbidden` while nothing reconciles.

**A writable `/tmp`.** Every sync writes the translated document to a temp file
under `os.TempDir()` before handing it to adc. Upstream never notices because its
distroless container has a writable rootfs. With `readOnlyRootFilesystem: true`
the pod comes up `2/2 Ready`, the GatewayClass reaches `Accepted=True`, and every
sync fails with `open /tmp/adc-task-<n>.json: read-only file system`. This chart
mounts an emptyDir there.

**`fsGroup`.** adc `chmod`s its socket to `0660` the instant it binds. Both
containers here run as uid/gid 1001, so the `quench-common` default
`fsGroup: 1001` is what lets the controller dial it. Raise `runAsUser` on one
container without the other and every sync fails with `EACCES` — again with both
probes green. Upstream needs `fsGroup: 2000` only because its two images run as
different users.

## RBAC

Transcribed from the controller's own `//+kubebuilder:rbac` markers at release
2.2.0 — the same source that generates upstream's `config/rbac/role.yaml` — not
inferred from what a controller probably needs.

* **ClusterRole**: read-only on everything it watches (core `configmaps`,
  `namespaces`, `pods`, `secrets`, `services`; `discovery.k8s.io`
  `endpointslices`; the twelve `apisix.apache.org` kinds; `networking.k8s.io`
  Ingress and IngressClass; the Gateway API kinds), `update` on ten CRD
  `/status` subresources plus `ingresses/status` and the Gateway API statuses,
  and `create`/`patch` on events. Cluster-wide because a route or a Secret may
  live in any namespace, and IngressClass and GatewayClass are cluster-scoped.
* **Role**, release namespace: leader-election Leases only. Upstream grants those
  cluster-wide; this chart narrows them because the Deployment pins
  `POD_NAMESPACE`. The two go together.

`gatewayclasses` carries `update` and not for its status: the controller puts an
`apisix.apache.org/gc-protection` finalizer on a class it claims.

Nothing is granted to create, patch or delete any workload — this controller
writes to APISIX, not to Kubernetes. Nothing at all is granted on core
`endpoints`; backend resolution goes through EndpointSlices.

`gatewayAPI.enabled: false` drops the Gateway API rules along with the watches.

## CRDs

`crds/apisix.apache.org.crds.yaml` holds the twelve `apisix.apache.org` CRDs of
release 2.2.0, vendored from the ASF source release's `config/crd/bases` with the
two `config/crd/patches` schema validations folded in — `kustomize build
config/crd` is upstream's own install step and those two `oneOf` rules cannot be
expressed as controller-gen markers.

They live in `crds/`, matching every other CRD-bearing quench chart. Helm
installs that directory once and never templates, upgrades or deletes it, which
is what keeps `helm uninstall` from taking a cluster's ApisixRoutes with it. A
chart upgrade that moves `appVersion` therefore leaves the old schemas in place;
re-apply them yourself:

```bash
helm show crds oci://ghcr.io/quenchworks/charts/apisix-ingress-controller \
  | kubectl apply --server-side -f -
```

`helm install --skip-crds` suppresses them, for clusters where CRDs are managed
by a separate pipeline.

## Configuration examples

Drive an existing APISIX outside this namespace, with a key you manage:

```yaml
dataPlane:
  endpoints: ["https://apisix-admin.gateway.svc.cluster.local:9180"]
  tlsVerify: true
  adminKey:
    existingSecret: apisix-admin
    existingSecretKey: key
```

Run without the Gateway API at all — no `gateway-api-crds` chart needed, and the
Gateway API RBAC is not granted:

```yaml
gatewayAPI:
  enabled: false
```

Be the cluster's default ingress controller:

```yaml
ingressClass:
  default: true
```

Two independent controllers in one cluster (change `controllerName` on both the
controller and its classes, which this chart does for you):

```yaml
controllerName: apisix.apache.org/team-b
ingressClass:
  name: apisix-team-b
```

Repair data-plane drift on a schedule rather than only on events:

```yaml
syncPeriod: 5m
initSyncDelay: 30s
```

## Smoke test

```bash
# 1. it claimed its classes
kubectl get ingressclass apisix -o jsonpath='{.spec.controller}'
kubectl get gatewayclass apisix \
  -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'    # True

# 2. a real route is reconciled AND pushed (Accepted goes True only after the
#    Admin API sync succeeds)
kubectl wait --for=condition=Accepted apisixroute/example

# 3. it serves, and an unrouted path does not
kubectl port-forward svc/dp-apisix 8080:9080 &
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/get    # 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/nope   # 404

# 4. no permission it is missing (a controller short a rule logs this and
#    silently does nothing, while its pod looks perfectly Ready)
kubectl logs deploy/aic-apisix-ingress-controller -c apisix-ingress-controller \
  | grep -E 'forbidden|cannot list'                                   # no output
```

## Uninstall

```bash
helm uninstall aic
```

**Delete your Gateways before the controller if `gatewayClass.create` was on.**
The controller holds an `apisix.apache.org/gc-protection` finalizer on its
GatewayClass and only removes it once no Gateway references the class. Uninstall
with a Gateway still standing and the GatewayClass is left stuck `Terminating`
forever — the controller that would clear the finalizer is gone — and the next
`helm install --wait` blocks on it. Recover with
`kubectl patch gatewayclass <name> -p '{"metadata":{"finalizers":[]}}' --type merge`.

Everything in `crds/` is left behind on purpose: deleting a CRD cascade-deletes
every object of that kind, including routes serving live traffic. The
configuration already pushed into APISIX also stays — it lives in the data plane,
not in this release.

## Verify the chart

```bash
cosign verify ghcr.io/quenchworks/charts/apisix-ingress-controller \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

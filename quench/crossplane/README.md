# Quenchworks Crossplane

Hardened [Crossplane](https://github.com/crossplane/crossplane), the CNCF
control-plane framework that turns Kubernetes into a universal API for
infrastructure, on a minimal, nonroot, 0-CVE image built from source,
cosign-signed and pinned by digest.

Ships the core control plane and the RBAC manager as two Deployments, cluster-wide
clean-room RBAC, and self-generated webhook TLS — no cert-manager, no external
dependency of any kind.

## Install

```bash
helm install crossplane oci://ghcr.io/quenchworks/charts/crossplane \
  --namespace crossplane-system --create-namespace
```

Then install a Provider (fully qualified references only — Crossplane has no
default registry):

```bash
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-nop
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-nop:v0.4.0
EOF

kubectl get provider.pkg -w      # INSTALLED=True HEALTHY=True
```

## Where the CRDs come from

**This chart has no `crds/` directory, on purpose.** Crossplane's ~20 core CRDs
(`Provider`, `Function`, `Configuration`, `CompositeResourceDefinition`,
`Composition`, `Operation`, `Usage`, …) travel inside the *image* at `/crds`, and
the `init` container runs `crossplane core init`, which applies them and then
migrates their storage version on every upgrade.

That is upstream's own design (their chart ships no `crds/` either) and it is the
right one here: Helm applies a `crds/` directory once on install and then never
touches it again, so a chart-shipped copy would silently drift out of step with the
controller after the first upgrade — and the storage-version migration would never
run. Keeping the CRDs in the image guarantees they are always the exact revision
the running binary understands.

Consequence: `helm uninstall` leaves the CRDs (and therefore your composite
resources) in place, which is the behaviour you want. Deleting them abandons every
managed resource in the cluster.

## The RBAC manager

`rbacManager.enabled` defaults to `true`, matching upstream, and you almost
certainly want it. It is not a nice-to-have:

* it grants a freshly installed Provider the permissions its package requested —
  without it, every `Provider` you apply stalls un-`Healthy` forever;
* it grants the *core* control plane access to the CRDs that Provider brings, by
  creating ClusterRoles labelled `rbac.crossplane.io/aggregate-to-crossplane`;
* it derives per-XRD `admin`/`edit`/`view`/`browse` ClusterRoles so a platform team
  can hand out one stable role name instead of tracking every composite API.

It runs as a **separate Deployment under its own ServiceAccount** because it needs
`escalate` and `bind` on ClusterRoles — rights the core control plane deliberately
does not hold. Merging it into the core pod would hand those rights to every
Crossplane controller.

Because it is enabled, the ClusterRole bound to the core ServiceAccount is
*aggregating* and carries no rules of its own; the static rules live in a second
`-system` ClusterRole labelled into it. That indirection is required, not stylistic:
Kubernetes overwrites the `rules` of any ClusterRole that has an `aggregationRule`,
so the manager could not add provider access to a role that also held static rules.
With `rbacManager.enabled: false` the rules go straight into the bound role.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/crossplane \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/crossplane --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/crossplane` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Extra replicas buy failover, not throughput (leader election). |
| `core.namespace` | `""` | Namespace packages are unpacked and run in. Empty = release namespace. |
| `core.leaderElection` | `true` | Lease-based. Required if `replicaCount > 1`. |
| `core.webhooks.enabled` | `true` | Usage-protection validating webhook + XRD conversion webhooks. |
| `core.webhooks.port` | `9443` | Webhook server container port. |
| `core.metricsPort` | `8080` | Prometheus `/metrics`. |
| `core.healthProbePort` | `8081` | `/healthz` and `/readyz`. |
| `core.syncInterval` | `""` | Full drift re-check period. Empty = upstream `1h`. |
| `core.pollInterval` | `""` | Per-resource poll period. Empty = upstream `1m`. |
| `core.maxConcurrentReconciles` | `""` | Worker pool size. Empty = upstream `100`. |
| `core.packages.providers` | `[]` | Providers pre-installed by `core init`. |
| `core.packages.functions` | `[]` | Functions pre-installed by `core init`. |
| `core.packages.configurations` | `[]` | Configurations pre-installed by `core init`. |
| `core.extraArgs` | `[]` | Feature gates etc., e.g. `["--enable-operations"]`. |
| `core.packageCache.sizeLimit` | `20Mi` | `emptyDir` for unpacked packages. Pure cache. |
| `core.functionCache.sizeLimit` | `128Mi` | `emptyDir` for memoised function responses. Pure cache. |
| `rbacManager.enabled` | `true` | See [The RBAC manager](#the-rbac-manager). |
| `rbacManager.replicaCount` | `1` | |
| `rbacManager.leaderElection` | `true` | |
| `rbacManager.aggregatedClusterRoles` | `true` | Create the `-admin`/`-edit`/`-view`/`-browse` roles. |
| `rbacManager.restrictProviderPermissions` | `false` | Cap provider requests to the `-allowed-provider-permissions` allow-list. |
| `rbacManager.resources` | `cpu 25m-250m / mem 64Mi-256Mi` | |
| `rbacManager.extraArgs` | `[]` | |
| `resources.requests` | `cpu 100m / mem 256Mi` | Applies to the core pod and its init container. |
| `resources.limits` | `cpu 1000m / mem 1Gi` | |
| `service.type` | `ClusterIP` | |
| `service.port` | `9443` | Webhook Service port. Part of the TLS contract. |
| `service.annotations` | `{}` | |
| `serviceAccount.create` | `true` | Token IS automounted — Crossplane is an API-server client. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `true` | Cluster-wide RBAC for the control plane and the RBAC manager. |
| `networkPolicy.enabled` | `false` | See [Networking](#networking). |
| `networkPolicy.allowExternal` | `true` | Must stay `true` for webhook admission to work. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

Two Deployments, one image, one multi-call binary:

| Deployment | init container | main container |
|---|---|---|
| `<release>-crossplane` | `crossplane core init` | `crossplane core start` |
| `<release>-crossplane-rbac-manager` | `crossplane rbac init` | `crossplane rbac start` |

`core init` applies the CRDs from `/crds`, registers the webhook configurations
from `/webhookconfigurations`, and mints a self-signed CA plus server and client
certificates into three `Secret`s that the chart creates **empty**. The chart has to
create them: a Pod's secret volumes are mounted before *any* container runs, init
containers included, so a Secret that does not exist yet leaves the Pod stuck in
`ContainerCreating` and the init container that would have created it never runs.
Creating them from the chart also means `helm uninstall` takes the CA with it.

`rbac init` blocks until the `compositeresourcedefinitions` and `providerrevisions`
CRDs exist, so the RBAC manager does not crashloop while racing `core init` on a
fresh install.

Liveness and readiness are `httpGet /healthz` and `/readyz` on port `8081`.
controller-runtime registers those handlers only after the manager — and, with
webhooks on, the webhook server — has actually started, so they are real readiness
signals rather than a bound socket. The RBAC manager has no probe server, so it is
probed on `httpGet /metrics`.

Both containers run nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped. Everything Crossplane writes is cache — `/cache/xpkg` for
unpacked packages, `/cache/xfn` for memoised composition-function responses — plus
`/tmp`; all three are `emptyDir`s, and losing them costs only a re-pull.

**One Crossplane per cluster.** Its CRDs, the aggregation labels the RBAC manager
writes, and the webhook configurations it registers are all cluster-scoped and not
namespaced by release, so a second release would fight the first over shared state.
That is also why the cluster-scoped RBAC names here are not namespace-suffixed the
way they are in the other Quenchworks charts — there is no multi-release scenario to
disambiguate, and the suffix would push `-allowed-provider-permissions` up against
Kubernetes' 63-character name limit.

## Networking

`networkPolicy.enabled` defaults to **false**. The API server initiates the
connection to the webhook port, and from a Pod's point of view it is off-cluster, so
a `podSelector`-only ingress rule silently breaks admission on every `Usage` and
XRD. Enable the policy only with `allowExternal: true` unless you have verified your
CNI treats the API server as an in-cluster peer.

## Configuration examples

Pre-install a function and a provider on first boot:

```yaml
core:
  packages:
    providers: ["xpkg.crossplane.io/crossplane-contrib/provider-nop:v0.4.0"]
    functions: ["xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2"]
```

Enable the Operations alpha feature and poll faster:

```yaml
core:
  extraArgs: ["--enable-operations"]
  pollInterval: "30s"
```

Highly available control plane:

```yaml
replicaCount: 2
core:
  leaderElection: true
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: crossplane
```

Cap what Provider packages may request:

```yaml
rbacManager:
  restrictProviderPermissions: true
```

Then widen the allow-list by labelling ClusterRoles with
`rbac.crossplane.io/aggregate-to-allowed-provider-permissions: "true"`. It starts
empty, so with nothing labelled every provider request is denied.

## Uninstall

```bash
helm uninstall crossplane -n crossplane-system
```

The core CRDs survive, so your composite resources and installed packages are still
described. Delete the CRDs only if you mean to abandon every managed resource
Crossplane created.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Crossplane is a control plane: it
holds `*` on `customresourcedefinitions` and creates the Deployments and
ServiceAccounts that run Provider packages, so anyone who can create a `Provider` in
your cluster can run arbitrary code with the permissions that package requests. Use
`rbacManager.restrictProviderPermissions` and normal RBAC on `pkg.crossplane.io`
accordingly.

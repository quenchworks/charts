# Quenchworks descheduler

Hardened [Kubernetes descheduler](https://github.com/kubernetes-sigs/descheduler)
on a minimal, nonroot, 0-CVE image, built from source and pinned by digest.

The descheduler periodically evicts running pods so the scheduler can reschedule
them onto more suitable nodes, correcting drift from node taints, affinity,
topology spread and utilisation over time.

## Install

```sh
helm install descheduler oci://ghcr.io/quenchworks/charts/descheduler
```

It runs nonroot as a Deployment and executes its descheduling loop every
`deschedulingInterval` (default `5m`). Watch it:

```sh
kubectl logs -l app.kubernetes.io/instance=descheduler -f
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/descheduler \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/descheduler --owner quenchworks`.

## Configuration

The chart ships a real cluster-scoped `ClusterRole`/`ClusterRoleBinding`
(`rbac.create=true`) granting the read + `pods/eviction` rights the descheduler
needs. The `DeschedulerPolicy` (`descheduler/v1alpha2`) is rendered from
`policy.config` to a ConfigMap, mounted at `/policy/policy.yaml` and passed via
`--policy-config-file`. Point `policy.existingConfigMap` (key `policy.yaml`) at an
externally-managed ConfigMap to use that instead.

Health and metrics are served over HTTPS on `metricsPort` (default `10258`);
liveness/readiness probe `/healthz` with scheme `HTTPS`.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/descheduler` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | only one active loop; use `leaderElection` for HA |
| `deschedulingInterval` | `5m` | loop interval |
| `leaderElection.enabled` | `false` | required when `replicaCount > 1`; adds leases RBAC |
| `policy.config` | (default policy) | inline `DeschedulerPolicy` (mounted, `--policy-config-file`) |
| `policy.existingConfigMap` | `""` | external policy ConfigMap (key `policy.yaml`, wins) |
| `verbosity` | `3` | `--v` log level |
| `extraArgs` | `[]` | appended to the `descheduler` command |
| `metricsPort` | `10258` | HTTPS `/healthz` + `/metrics` |
| `service.enabled` | `true` | ClusterIP Service for scraping metrics |
| `rbac.create` | `true` | ClusterRole + ClusterRoleBinding |
| `networkPolicy.enabled` | `true` | ingress restricted to namespace by default |
| `podDisruptionBudget.enabled` | `false` | enable with HA (`replicaCount > 1`) |

## High availability

For HA run multiple replicas with leader election so exactly one instance is
active at a time:

```sh
helm install descheduler oci://ghcr.io/quenchworks/charts/descheduler \
  --set replicaCount=2 --set leaderElection.enabled=true \
  --set podDisruptionBudget.enabled=true
```

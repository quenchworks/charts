# Quenchworks Redis

Hardened Redis on a minimal, nonroot, 0-CVE image pinned by digest.

## Install

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis
```

By default auth is on and a password is generated into a Secret. To set your own:

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis \
  --set auth.password='change-me'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/redis \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/redis` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `architecture` | `standalone` | `standalone` or `replication`. |
| `auth.enabled` | `true` | Sets `--requirepass`. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `config` | appendonly + save | Rendered into a ConfigMap as `redis.conf`. |
| `existingConfigmap` | `""` | Use your own ConfigMap instead. |
| `extraFlags` | `[]` | Extra server flags. |
| `tls.enabled` | `false` | In-transit TLS from `tls.existingSecret`. |
| `primary.replicaCount` | `1` | |
| `primary.persistence.enabled` | `true` | 8Gi PVC by default. |
| `replica.replicaCount` | `2` | Only when `architecture=replication`. |
| `replica.autoscaling.enabled` | `false` | HPA on replica CPU. |
| `metrics.enabled` | `false` | redis_exporter sidecar (our hardened image). |
| `metrics.serviceMonitor.enabled` | `false` | Prometheus Operator ServiceMonitor. |
| `metrics.prometheusRule.enabled` | `false` | Alerting rules. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Architecture

Standalone runs a single primary. Replication adds read replicas that follow the primary with
`replicaof` over the headless service, sharing the same auth and TLS material. For high
availability with automatic failover, see [Sentinel in the roadmap](../../../.github/ROADMAP.md).

## Notes

The chart depends on the `quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. Every
container runs as nonroot on a read-only root filesystem with all capabilities dropped, and both
the server and the metrics sidecar are pinned by digest.

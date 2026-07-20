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

## Standalone vs HA

Standalone is the default: a single primary, no failover. For automatic failover,
switch to replication with Sentinel:

```bash
# Standalone (default): 1 primary, no failover, smallest footprint
helm install my-redis oci://ghcr.io/quenchworks/charts/redis

# HA: 1 primary + N replicas + a 3-node Sentinel quorum with automatic failover
helm install my-redis oci://ghcr.io/quenchworks/charts/redis \
  --set architecture=replication --set sentinel.enabled=true
```

Standalone is one pod, so its loss is downtime until it restarts. HA promotes a
replica to primary automatically when the primary is lost, at the cost of extra
replica and Sentinel pods. See [Architecture](#architecture) for the Sentinel
topology, the client read/write paths, and the failover boundaries.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/redis \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/redis \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/redis` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `architecture` | `standalone` | `standalone` or `replication`. |
| `sentinel.enabled` | `false` | HA with automatic failover (needs `architecture=replication`). |
| `sentinel.replicaCount` | `3` | Sentinel quorum size. |
| `sentinel.quorum` | `2` | Sentinels that must agree the primary is down. |
| `sentinel.downAfterMilliseconds` | `5000` | Time a primary is unreachable before it is `sdown`. |
| `sentinel.failoverTimeout` | `180000` | Failover retry/backoff window (ms). |
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
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` (plus a Sentinel PDB at `minAvailable: quorum`). |

## Architecture

Standalone runs a single primary. Replication adds read replicas that follow the primary with
`replicaof` over the headless service, sharing the same auth and TLS material.

### High availability (Sentinel)

Set `architecture=replication` and `sentinel.enabled=true` for a self-managed HA topology with
automatic failover — no operator, no managed service:

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis \
  --set architecture=replication --set sentinel.enabled=true
```

You get one primary (StatefulSet ordinal 0 at bootstrap), N read replicas, and a 3-node **Redis
Sentinel** quorum. Each pod discovers the current master from Sentinel at startup, so roles stay
correct across restarts. Two client paths:

- **Write / discovery** — the `*-sentinel` Service (port 26379). Clients ask
  `SENTINEL get-master-addr-by-name mymaster` for the live master. This is the correct write path
  in HA mode; the current master changes on failover.
- **Read** — the `*-replica` Service (port 6379), all replicas.

**Failover.** When the primary is lost, the Sentinels reach quorum, elect a leader, and promote a
replica to master (typically within ~10s of `downAfterMilliseconds`). Surviving replicas
re-sync from the new master, and the old primary rejoins as a replica when it restarts. Quorum
(majority) loss is deliberately *not* auto-rebuilt — that needs a human, to avoid split-brain.
Per-pod PVCs, soft pod anti-affinity, and a Sentinel PodDisruptionBudget (`minAvailable: quorum`)
back the topology. Auth (`requirepass`/`masterauth`) and TLS are carried through to Sentinel.

The redis and redis-sentinel containers stay **shell-free**: the rewritable Sentinel config and
the boot-time master discovery run in init containers on the hardened `busybox` helper image
(`busybox.repository`/`busybox.digest`, pinned by digest), writing their output into an emptyDir the
redis containers then consume.

## Notes

The chart depends on the `quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. Every
container runs as nonroot on a read-only root filesystem with all capabilities dropped, and both
the server and the metrics sidecar are pinned by digest.

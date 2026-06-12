# Quenchworks ScyllaDB

Hardened **ScyllaDB Open Source** on a minimal, nonroot, 0-CVE image pinned by
digest. ScyllaDB is a high-throughput, Cassandra-compatible (CQL) database. The
image ships ScyllaDB's official relocatable binary on a hardened Wolfi base; its
entrypoint seeds `scylla.yaml` from `SCYLLA_*` env on boot and runs Scylla in
container/developer mode so it works in an unprivileged, read-only-rootfs pod.

> **License:** ScyllaDB Open Source is **AGPL-3.0-only** (OSI-approved). The image
> redistributes the upstream binary unmodified and carries its NOTICE/licenses.

## Install

```bash
helm install sc oci://ghcr.io/quenchworks/charts/scylladb
```

Tune it:

```bash
helm install sc oci://ghcr.io/quenchworks/charts/scylladb \
  --set config.smp=2 --set config.memory=4G \
  --set resources.requests.memory=4Gi --set resources.limits.memory=6Gi \
  --set persistence.size=50Gi
```

> **Memory is a hard cap.** `config.memory` (`SCYLLA_MEMORY` → `--memory`) bounds the
> Seastar allocator. Seastar's available-memory probe is conservative inside a cgroup,
> so keep `config.memory` **well under** `resources.requests.memory` (the default is
> `512M` under a `1Gi` request / `2Gi` limit). If you raise `config.memory`, raise the
> request and limit together with extra headroom — otherwise Scylla either fails its
> startup memory check or is OOMKilled.

## Connect

The runtime image has no in-image `cqlsh`, so connect with a throwaway upstream
client pod:

```bash
kubectl run cqlclient --rm -it --restart=Never --image=scylladb/scylla:6.2 -- \
  cqlsh sc-scylladb 9042
```

```sql
CREATE KEYSPACE IF NOT EXISTS demo WITH replication =
  {'class':'SimpleStrategy','replication_factor':1};
CREATE TABLE IF NOT EXISTS demo.t(id int PRIMARY KEY, v text);
INSERT INTO demo.t(id, v) VALUES (1, 'quench');
SELECT v FROM demo.t WHERE id = 1;
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/scylladb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Authentication

Auth is **off by default** — this is an internal deployment and the NetworkPolicy
is the trust boundary. Enable login auth with:

```bash
helm install sc oci://ghcr.io/quenchworks/charts/scylladb --set auth.enabled=true
```

This sets `PasswordAuthenticator` + `CassandraAuthorizer`, and Scylla bootstraps the
default `cassandra` / `cassandra` superuser. **Rotate it immediately:**

```sql
ALTER ROLE cassandra WITH PASSWORD = '<new-strong-password>';
```

## Clustering

Single standalone node by default (`seeds = self`). Multi-node rings via
`replicaCount > 1` wire the first `config.seedCount` pods as `SCYLLA_SEEDS` over the
headless service; this path is a tracked follow-up and not yet validated at scale.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/scylladb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; keep at 1 (multi-node is a follow-up). |
| `config.clusterName` | `Quench Cluster` | Must match across all nodes in a ring. |
| `config.smp` | `1` | CPU shares Scylla pins (`SCYLLA_SMP` → `--smp`). |
| `config.memory` | `512M` | **Hard memory cap** (`SCYLLA_MEMORY` → `--memory`). Keep well under `resources.requests.memory`. |
| `config.developerMode` | `true` | Relaxes AIO/fs/clocksource checks for containers. |
| `config.reactorBackend` | `epoll` | Avoids io_uring/AIO when the kernel/seccomp blocks it. |
| `config.overprovisioned` | `true` | Yields CPU in shared environments. |
| `config.seedCount` | `1` | Stable seed pods for multi-node, clamped to `replicaCount`. |
| `config.yamlExtra` | `""` | Raw `scylla.yaml` appended verbatim. |
| `auth.enabled` | `false` | Toggle PasswordAuthenticator + CassandraAuthorizer. |
| `persistence.enabled` | `true` | 16Gi PVC per pod at `/var/lib/scylla`. |
| `service.cqlPort` | `9042` | CQL client port (ClusterIP + headless). |
| `service.apiPort` | `10000` | REST API (health/admin); ClusterIP, in-cluster only. |
| `service.internodePort` | `7000` | Gossip/storage (headless only). |
| `networkPolicy.enabled` | `true` | Ingress to internode + REST (own pods) + CQL (clients). |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only `/var/lib/scylla` (PVC — data/commitlog/hints) and `/etc/scylla`
(emptyDir — conf, seeded on first boot) are writable; both are exec-capable because
the bundled libreloc loader mmaps from them. Readiness gates on the unauthenticated
REST API (`GET /storage_service/scylla_release_version` on port 10000), so a pod only
takes traffic once the storage service is up. Prometheus metrics (9180) and the
Alternator DynamoDB API (8000) are **not** exposed by default.

## Notes

Single standalone node by default. Depends on the `quench-common` library chart,
pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

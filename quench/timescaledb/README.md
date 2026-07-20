# Quenchworks TimescaleDB

Hardened TimescaleDB on a minimal, nonroot, 0-CVE image pinned by digest. The image
is PostgreSQL 17 plus the open-source (Apache-2.0) TimescaleDB extension. It runs
`initdb` and `CREATE EXTENSION timescaledb` on first boot, then serves; the chart
pins it by the signed digest. Use it for hypertables, continuous aggregates, native
compression, and other time-series workloads on a normal PostgreSQL wire protocol.

## Install

```bash
helm install my-tsdb oci://ghcr.io/quenchworks/charts/timescaledb
```

By default auth is on and a superuser password is generated into a Secret. To set
your own and create an application database:

```bash
helm install my-tsdb oci://ghcr.io/quenchworks/charts/timescaledb \
  --set auth.password='change-me' \
  --set auth.database='myapp'
```

## Standalone vs HA

The chart ships two topologies, selected by `architecture`:

- **`standalone`** (default) — a single TimescaleDB pod. Backward compatible; the
  image runs `initdb` + `CREATE EXTENSION timescaledb` on first boot.
- **`replication`** — a self-managed HA cluster of `ha.replicaCount` pods (default 3:
  **1 leader + 2 replicas**) in one StatefulSet, each running
  [Patroni](https://patroni.readthedocs.io/). Patroni elects a leader through the
  **Kubernetes API as its DCS** (no external etcd), drives PostgreSQL streaming
  replication, and rejoins a demoted node with `pg_rewind`. `shared_preload_libraries`
  is set to `timescaledb` cluster-wide and the extension is created on bootstrap, so
  hypertables and continuous aggregates keep working across a failover.

```bash
helm install my-tsdb oci://ghcr.io/quenchworks/charts/timescaledb \
  --set architecture=replication \
  --set auth.database=myapp
```

Services follow the elected leader via a `role=master|replica` pod label Patroni
maintains:

| Service | Selects | Use for |
|---------|---------|---------|
| `<release>-timescaledb` / `<release>-timescaledb-primary` | current leader | reads + writes |
| `<release>-timescaledb-replica` | streaming standbys | read-only fan-out |
| `<release>-timescaledb-headless` | all members | stable per-pod DNS |

Inspect the cluster and watch failover:

```bash
kubectl exec <release>-timescaledb-0 -- patronictl list
```

Shows one `Leader` and the replicas as `streaming`. Kill the leader pod and Patroni
promotes a replica within a few seconds; the primary Service repoints automatically
and the old node rejoins as a replica. A `PodDisruptionBudget` (`minAvailable: 2` of
3) keeps voluntary drains from breaking quorum. HA adds a namespaced Patroni Role
(configmaps/endpoints/pods/services/events), ServiceAccount token automount, and a
NetworkPolicy port for the Patroni REST API (8008).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/timescaledb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/timescaledb \
  --owner quenchworks
```

## Verify the extension

```bash
psql ... -tAc "SELECT extversion FROM pg_extension WHERE extname='timescaledb'"
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/timescaledb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `architecture` | `standalone` | `standalone` (1 pod) or `replication` (Patroni HA). |
| `ha.replicaCount` | `3` | HA cluster members (odd count; 1 leader + N-1 replicas). |
| `ha.replicationUsername` | `replicator` | Streaming-replication role Patroni creates. |
| `ha.persistence.enabled` | `true` | Per-member 8Gi PVC in HA mode. |
| `ha.extraParameters` | `{}` | Extra `postgresql.parameters` merged into Patroni's bootstrap config. |
| `ha.podDisruptionBudget.minAvailable` | `2` | Keeps a 3-node cluster above quorum on drains. |
| `auth.enabled` | `true` | PostgreSQL needs a superuser password to initialize. |
| `auth.username` | `postgres` | Superuser created by initdb. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional extra database created on first boot. |
| `primary.persistence.enabled` | `true` | 8Gi PVC; PGDATA lives in a subdir of it. |
| `primary.shmVolume.enabled` | `true` | Memory-backed `/dev/shm` for parallel queries. |
| `service.port` | `5432` | |
| `metrics.enabled` | `false` | Hardened postgres_exporter sidecar (works against TimescaleDB). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. PGDATA, the socket dir, `/tmp`, and `/dev/shm` are the only writable mounts.

## Notes

Standalone by default; set `architecture: replication` for the self-managed Patroni
HA cluster (see above). In standalone the image loads the TimescaleDB extension on
first init; in HA the chart's Patroni bootstrap preloads it cluster-wide and creates
it on the leader. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

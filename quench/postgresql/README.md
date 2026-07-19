# Quenchworks PostgreSQL

Hardened PostgreSQL on a minimal, nonroot, 0-CVE image pinned by digest. The image
runs `initdb` on first boot, then serves; the chart pins it by the signed digest.

## Install

```bash
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql
```

By default auth is on and a superuser password is generated into a Secret. To set
your own and create an application database:

```bash
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql \
  --set auth.password='change-me' \
  --set auth.database='myapp'
```

## Standalone vs HA

The chart runs in two modes. Standalone is the default.

```bash
# Standalone: one postgres pod, no failover. Dev/test or small workloads.
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql

# HA: a Patroni-managed cluster (1 leader + 2 replicas) with automatic failover.
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql \
  --set architecture=replication
```

Standalone is a single pod with no fault tolerance and a smaller footprint. HA runs
`ha.replicaCount` nodes (3 by default) and promotes a replica automatically on
leader loss. See below for the HA details.

## High availability (Patroni)

Set `architecture: replication` to run a self-managed HA cluster instead of a single
node. Each pod runs [Patroni](https://patroni.readthedocs.io/), which supervises
postgres, elects a leader through the Kubernetes API, and drives streaming
replication. There is no external etcd — Patroni stores cluster state in ConfigMaps
in the release namespace and stamps a `role=master|replica` label on each pod.

```bash
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql \
  --set architecture=replication \
  --set ha.replicaCount=3 \
  --set auth.password='change-me' \
  --set auth.database='myapp'
```

You get three Services:

| Service | Selects | Use for |
|---------|---------|---------|
| `<release>-postgresql` / `<release>-postgresql-primary` | `role=master` | reads **and** writes (the current leader) |
| `<release>-postgresql-replica` | `role=replica` | read-only queries, spread across the standbys |
| `<release>-postgresql-headless` | all members | stable per-pod DNS (Patroni peering) |

**Failover.** When the leader dies, the members race for the leader lock in the DCS;
the winner promotes in a few seconds and Patroni flips its `role` label to `master`,
so the primary Service's endpoints follow it automatically — clients reconnecting to
the same Service name land on the new leader. The old node rejoins as a replica when
it returns: if it diverged (accepted writes the cluster never saw) `pg_rewind`
rewinds it to the new timeline; otherwise it just streams from the new leader.

**RBAC.** HA mode needs the pod's ServiceAccount to reach the Kubernetes API, so the
chart creates a namespaced `Role` (configmaps, endpoints, pods, services, events) +
`RoleBinding` and turns on token automount — regardless of `rbac.create`. Nothing is
cluster-scoped. In standalone mode the pod never calls the API and the token stays off.

**Quorum boundary.** The PodDisruptionBudget defaults to `minAvailable: 2` so a
voluntary drain can never take a 3-node cluster below a majority. Losing the majority
(2 of 3 at once) is **not** auto-rebuilt — that risks split-brain, so it surfaces as a
stuck cluster for an operator to resolve, rather than a silent, unsafe promotion.
Run an odd `ha.replicaCount` (3 or 5) so a majority is always unambiguous.

Inspect the cluster any time:

```bash
kubectl exec <release>-postgresql-0 -- patronictl list
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgresql \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/postgresql \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/postgresql` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `architecture` | `standalone` | `replication` runs a Patroni HA cluster (see above). |
| `ha.replicaCount` | `3` | HA members. Keep it odd for an unambiguous majority. |
| `ha.replicationUsername` | `replicator` | Streaming-replication role Patroni creates. |
| `ha.persistence.size` | `8Gi` | Per-pod PVC (one per member). |
| `ha.podDisruptionBudget.minAvailable` | `2` | Keeps a drain above quorum. |
| `ha.extraParameters` | `{}` | Extra cluster-wide `postgresql.parameters`. |
| `auth.enabled` | `true` | PostgreSQL needs a superuser password to initialize. |
| `auth.username` | `postgres` | Superuser created by initdb. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional extra database created on first boot. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC; PGDATA lives in a subdir of it. |
| `primary.shmVolume.enabled` | `true` | Memory-backed `/dev/shm` for parallel queries. |
| `service.port` | `5432` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. PGDATA, the socket dir, `/tmp`, and `/dev/shm` are the only writable mounts.

## Notes

Standalone is the default; set `architecture: replication` for a Patroni HA cluster
(above). The metrics exporter sidecar currently attaches to standalone only — per-pod
metrics for the HA members are a follow-up. The chart depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

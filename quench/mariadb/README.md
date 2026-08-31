# Quenchworks MariaDB

Hardened MariaDB on a minimal, nonroot, 0-CVE image pinned by digest. The image runs
`mariadb-install-db` on first boot, applies setup via a temporary local server, then
serves; the chart pins it by the signed digest.

## Install

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb
```

Set your own root password and create an application database + user:

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb \
  --set auth.rootPassword='change-me' \
  --set auth.database='myapp' \
  --set auth.username='app' --set auth.password='app-pass'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mariadb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/mariadb \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mariadb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.rootPassword` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional application database created on first boot. |
| `auth.username` / `auth.password` | `""` | Optional application user (password generated if empty). |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/mysql`. |
| `service.port` | `3306` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `metrics.enabled` | `false` | mysqld_exporter sidecar (our hardened image) in every server pod. |
| `metrics.port` | `9104` | Scrape port; a `<release>-mariadb-metrics` Service fronts it. |
| `metrics.extraArgs` | `[]` | Extra mysqld_exporter flags. |
| `metrics.serviceMonitor.enabled` | `false` | Prometheus Operator ServiceMonitor. |
| `metrics.prometheusRule.enabled` | `false` | Alerting rules (down, connection saturation). |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` standalone; quorum (2 of 3) in Galera mode. |
| `architecture` | `standalone` | Set to `galera` for the HA cluster. |
| `galera.replicaCount` | `3` | Node count. Keep it odd (3, 5, ...). |
| `galera.clusterName` | `quench-galera` | wsrep cluster name. |
| `galera.sstMethod` | `mariabackup` | Hot state-snapshot transfer method. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/mysql`, the socket dir, and `/tmp` are writable.

## High availability (Galera)

Set `architecture: galera` for a synchronous multi-primary cluster:

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb \
  --set architecture=galera \
  --set auth.rootPassword='change-me' --set auth.database='myapp'
```

**Topology.** Three nodes (odd count for a clear quorum) run as a StatefulSet behind a
headless Service for stable per-pod DNS, each with its own PVC. Every node is a primary:
any node accepts writes, and Galera certifies each transaction across the cluster before
commit, so replication is synchronous and there is no failover gap or promotion step. The
client Service load-balances across all Ready nodes.

**Bootstrap vs. join.** Galera's cold-start hazard is that every node waits for the
others. The entrypoint breaks the tie: node-0 forms a new cluster (`--wsrep-new-cluster`)
only when no other member is already reachable on the gcomm port; otherwise it — and every
other ordinal — joins the existing cluster and pulls a state snapshot. That same
"is a peer live?" check is the split-brain guard when node-0 restarts: it rejoins rather
than starting a second cluster.

**SST.** A joining node is seeded from a live donor with `mariabackup` (a hot, physical
snapshot — the donor keeps serving during the copy). Readiness gates on
`wsrep_local_state_comment = Synced`, so a node mid-transfer is kept out of the Service
until it has caught up.

**Quorum boundary.** The PodDisruptionBudget holds `minAvailable` at the majority (2 of
3). Losing one node keeps the cluster writable and the node rejoins automatically (IST if
its gcache still has the writesets, otherwise a full SST). Losing the majority is **not**
auto-recovered — that is a deliberate split-brain stop that needs a human to pick the most
advanced survivor and bootstrap from it.

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

## Metrics

`metrics.enabled=true` adds a `mysqld_exporter` sidecar to **every** server pod — the
standalone primary and each Galera node — so metrics are per-node, not per-cluster. It
reaches the server over the pod's loopback and takes the root password from the auth
Secret via `MYSQLD_EXPORTER_PASSWORD` (never a DSN, so a password with URI metacharacters
needs no percent-encoding). A `<release>-mariadb-metrics` Service exposes port 9104, and
the NetworkPolicy opens it when metrics are on.

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb \
  --set metrics.enabled=true --set metrics.serviceMonitor.enabled=true
```

The exporter image is pinned by digest like the server. Galera's own `wsrep_*` counters
come through as `mysql_global_status_wsrep_*`. For a least-privilege scrape user instead
of root, leave `metrics.enabled=false` and attach your own exporter through `sidecars:`.

# Quenchworks MySQL

Hardened MySQL on a minimal, nonroot, 0-CVE image pinned by digest. The image runs
`mysql-install-db` on first boot, applies setup via a temporary local server, then
serves; the chart pins it by the signed digest.

## Install

```bash
helm install my-mysql oci://ghcr.io/quenchworks/charts/mysql
```

Set your own root password and create an application database + user:

```bash
helm install my-mysql oci://ghcr.io/quenchworks/charts/mysql \
  --set auth.rootPassword='change-me' \
  --set auth.database='myapp' \
  --set auth.username='app' --set auth.password='app-pass'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mysql \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/mysql \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mysql` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.rootPassword` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional application database created on first boot. |
| `auth.username` / `auth.password` | `""` | Optional application user (password generated if empty). |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/mysql`. |
| `service.port` | `3306` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` standalone; quorum (2 of 3) in HA mode. |
| `architecture` | `standalone` | Set to `group-replication` for the HA cluster. |
| `ha.replicaCount` | `3` | Group size. Keep it odd (3, 5, ...) for a clear majority. |
| `ha.groupName` | (UUID) | Fixed `group_replication_group_name` shared by all members. |
| `ha.replicationUsername` | `replicator` | Distributed-recovery user (password auto-generated into the Secret). |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/mysql`, the socket dir, and `/tmp` are writable.

## Standalone vs. HA (Group Replication)

The chart ships two topologies. `architecture: standalone` (the default) is a single
primary — backward compatible and unchanged. `architecture: group-replication` runs a
self-managed HA cluster using **MySQL Group Replication in single-primary mode**: one
PRIMARY (read/write) plus two SECONDARY members (read-only), with **automatic primary
election** on failure, built on the server's own `group_replication` plugin.

```bash
helm install my-mysql oci://ghcr.io/quenchworks/charts/mysql \
  --set architecture=group-replication \
  --set auth.rootPassword='change-me' --set auth.database='myapp'
```

**Topology.** Three nodes (odd count for an unambiguous majority) run as one
StatefulSet behind a headless Service for stable per-pod DNS, each with its own PVC.
GTID-based replication is single-primary: only the elected primary accepts writes; the
secondaries are held `super_read_only`. Two role-following Services front the group —
`<release>-mysql` targets the current **primary** (read/write) and
`<release>-mysql-readonly` fans reads over the **secondaries**. The entrypoint stamps a
`mysql.quench-works.com/role` label on each pod from its live GR role, so both Services
track elections automatically (a small namespaced RBAC Role lets the pod patch its own
label).

**Bootstrap vs. join.** The cold-start hazard is every node waiting for the others. The
entrypoint breaks the tie: node-0 forms a new group
(`group_replication_bootstrap_group=ON; START GROUP_REPLICATION`) **only** when no peer
already reports an ONLINE member; otherwise it — and every other ordinal — joins the
existing group. That same "is a peer ONLINE?" check is the split-brain guard when node-0
restarts: it rejoins rather than forming a second group. Readiness gates on
`MEMBER_STATE = ONLINE`, so a node mid distributed-recovery stays out of the Services.

**Failover.** Kill the primary and Group Replication auto-elects a surviving secondary as
the new primary within seconds; the role labels flip, the rw Service follows the new
primary, and the old node rejoins as a secondary when it returns.

**Inspect the group** from any member:

```bash
kubectl exec <release>-mysql-0 -- \
  mysql -uroot -p"<root-password>" \
  -e "SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members"
```

**Quorum boundary.** The PodDisruptionBudget holds `minAvailable` at the majority (2 of 3).
Losing one node keeps the group writable and the node rejoins automatically. Losing the
majority is **not** auto-recovered — that is a deliberate split-brain stop needing a human
to pick the most advanced survivor. Note: all replicated tables need a primary key (a
Group Replication requirement).

## Notes

A metrics exporter sidecar and custom `my.cnf` tuning are tracked as follow-ups. Depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

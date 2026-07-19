# Quenchworks etcd

Hardened etcd on a minimal, nonroot, 0-CVE image pinned by digest. Ships as a
highly available Raft cluster by default; the image is configured entirely
through `ETCD_*` env vars.

## Install

```bash
helm install my-etcd oci://ghcr.io/quenchworks/charts/etcd
```

## Standalone vs HA

The chart ships an HA 3-node Raft cluster by default. For dev/test or a small
footprint, run a single node instead:

```bash
# Standalone: 1 node, no fault tolerance, smallest footprint
helm install my-etcd oci://ghcr.io/quenchworks/charts/etcd \
  --set replicaCount=1

# HA (default): 3-node Raft cluster with automatic leader election and failover
helm install my-etcd oci://ghcr.io/quenchworks/charts/etcd
```

Standalone is one pod with a single PVC and no quorum, so a pod or node loss is
downtime until it restarts. HA runs 3 members (keep the count odd) and survives
one member down with zero-touch recovery, at the cost of 3x the pods and storage.
See [High availability](#high-availability) for the failover behavior and its
boundaries.

## High availability

The chart deploys a 3-node etcd cluster (a `StatefulSet` + headless `Service`)
with automatic leader election and failover. This is native to etcd — Raft
consensus, no sidecar or external operator.

- **Quorum**: `replicaCount` defaults to `3` (tolerates 1 member down). Use an
  **odd** count so a majority always exists; `5` tolerates 2. `1` is single-node
  with no fault tolerance.
- **Peer discovery**: members find each other over stable headless-Service DNS
  (`<sts>-N.<sts>-headless`). `--initial-cluster` is the full static peer list,
  rendered from `replicaCount` at template time.
- **Parallel bootstrap**: `podManagementPolicy: Parallel` — all members start
  together to form the initial quorum (ordered startup would deadlock, since
  member 0 can't become Ready until its peers exist).
- **Node spread**: a soft `podAntiAffinity` places members on distinct nodes
  when capacity allows (override with `.Values.affinity`).
- **PodDisruptionBudget**: `minAvailable: 2` so a voluntary drain can never take
  the 3-node cluster below quorum.
- **Per-pod storage**: each member gets its own PVC (`volumeClaimTemplate`) —
  never a shared disk.
- **Two Services**: a client `Service` on `2379` load-balanced across all ready
  members, and the headless `Service` (`2379`/`2380`) for peer identity.

### Failover / self-healing

- **Member/pod loss** (T1): the StatefulSet recreates the pod; it reattaches its
  PVC and rejoins by replaying its WAL. Zero-touch. `initialClusterState` is only
  read on a member's *first* boot with an empty data dir — on restart etcd reads
  the WAL and rejoins regardless, so leaving it at `new` is correct.
- **Node loss** (T2): the pod reschedules (anti-affinity spreads members) and its
  PVC reattaches.
- **Quorum loss is NOT auto-rebuilt.** Losing a majority (2 of 3) is
  split-brain territory and requires a human. Restore/recreate deliberately.

Kill-the-leader is safe: delete the leader pod and the two survivors elect a new
leader (Raft term advances) while the cluster stays writable; the deleted pod
rejoins on restart.

### Growing / re-adding members

Raising `replicaCount` after bootstrap does **not** auto-join new members — etcd
forbids implicit membership changes. To add or re-add a member (e.g. one whose
data was wiped), register it first with `etcdctl member add`, then bring the pod
up with `initialClusterState: existing`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/etcd \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/etcd \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/etcd` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `3` | HA Raft cluster. Use an odd number for quorum. |
| `initialClusterState` | `new` | `new` to bootstrap; `existing` only for manual member re-add. |
| `persistence.enabled` | `true` | 8Gi PVC per member at `/data`. |
| `service.clientPort` | `2379` | Client Service across all ready members. |
| `service.peerPort` | `2380` | Peer traffic over the headless Service. |
| `metrics.serviceMonitor.enabled` | `false` | etcd serves `/metrics` natively on the client port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Peer traffic allowed between members; client ingress from the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 2` (quorum of 3). |
| `affinity` | `{}` | Set to override the default soft node-spread anti-affinity. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/data` volume is writable.

## Notes

etcd RBAC auth / mTLS between peers and clients are tracked as follow-ups.
Metrics need no exporter: etcd exposes Prometheus metrics on the client port at
`/metrics`.

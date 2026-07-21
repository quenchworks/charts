# Quenchworks Dragonfly

> **LICENSE WARNING — Dragonfly is BSL-1.1 (Business Source License), NOT OSI-approved
> open source.** Each release converts to Apache-2.0 only years after publication.
> Do not represent Dragonfly as open source.
>
> **Clean alternative: [Valkey](../valkey) (BSD-3-Clause, already shipped) covers the
> same Redis-compatible cache slot with a true open-source license — prefer it.**

Hardened Dragonfly (a Redis/Memcached-compatible in-memory datastore) on a minimal, nonroot,
0-CVE image pinned by digest. Caution tier.

## Install

```bash
helm install my-dragonfly oci://ghcr.io/quenchworks/charts/dragonfly
```

Prefer the open-source option instead:

```bash
helm install my-valkey oci://ghcr.io/quenchworks/charts/valkey
```

Auth is off by default (matching the image; Dragonfly is open on the wire, so the
NetworkPolicy is the security boundary). To require a password:

```bash
helm install my-dragonfly oci://ghcr.io/quenchworks/charts/dragonfly \
  --set auth.enabled=true --set auth.password='change-me'
```

## Connect

Dragonfly speaks the Redis RESP protocol, so any `redis-cli` works against port 6379:

```bash
kubectl run rediscli --rm -i --restart=Never --image=redis:7-alpine -- \
  redis-cli -h my-dragonfly -p 6379 SET hello quench
kubectl run rediscli --rm -i --restart=Never --image=redis:7-alpine -- \
  redis-cli -h my-dragonfly -p 6379 GET hello
```

## Standalone vs HA

The chart runs in three modes.

| Mode | `architecture` / `sentinel.enabled` | Topology | Failover |
|------|--------------------------------------|----------|----------|
| **Standalone** (default) | `standalone` | 1 node | none (single node) |
| **Replication** | `replication` / `false` | 1 primary + N read replicas | **manual / operator-driven** |
| **HA** | `replication` / `true` | 1 primary + 2 replicas + 3 Sentinels | **automatic** |

### HA — automatic failover (validated on kind)

```bash
helm install my-dragonfly oci://ghcr.io/quenchworks/charts/dragonfly \
  --set architecture=replication --set sentinel.enabled=true --set auth.enabled=true
```

Dragonfly speaks the Redis replication protocol (`REPLICAOF` / `INFO replication`) and,
crucially, reports a Sentinel-compatible `INFO replication` (role, `connected_slaves`,
`slave0:…state=online`, `master_link_status`). Dragonfly ships **no sentinel binary of its
own**, so the Sentinels run `valkey-sentinel` from the QuenchWorks Valkey image — same RESP
+ Sentinel API. Three Sentinels monitor the Dragonfly primary; on primary loss they reach
quorum and promote a replica (`SLAVEOF NO ONE`), reconfiguring the survivors to follow it.
This was verified on kind: killing the primary promoted a replica in a few seconds, writes
landed on the new master, and the restarted old primary rejoined as a replica with its data
intact.

Config seeding and boot-time master discovery run in a hardened busybox init container that
writes a Dragonfly flagfile into an `emptyDir`, so a promoted replica keeps its role and a
restarted node always rejoins whichever node Sentinel currently reports as master (never the
dead pre-failover one). The Dragonfly image itself is unchanged.

Sentinel-aware clients should discover the current master rather than hard-code a host:

```bash
# against the sentinel Service on :26379
redis-cli -h my-dragonfly-sentinel -p 26379 SENTINEL get-master-addr-by-name mymaster
```

The primary Service (`my-dragonfly`) always selects the node currently labelled primary, so
plain clients can still write to it.

> Sentinel's instance-tracking relies on `run_id`, which Dragonfly's `INFO server` does not
> expose. Failover was nonetheless reliable in testing; this is why the Sentinel binary comes
> from the Valkey image rather than an unverified path. If you need a fully open-source
> Sentinel-HA cache, **[Valkey](../valkey)** is the clean-licensed alternative.

### Replication without Sentinel — manual failover

```bash
helm install my-dragonfly oci://ghcr.io/quenchworks/charts/dragonfly \
  --set architecture=replication --set sentinel.enabled=false
```

Replicas statically `REPLICAOF` the bootstrap primary (`…-primary-0`). There is **no
automatic promotion**: to fail over, an operator issues `REPLICAOF NO ONE` against the chosen
replica and repoints the others.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dragonfly \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/dragonfly --owner quenchworks`.

## Memory contract (important)

Dragonfly refuses to start unless `maxmemory >= threads * 256MiB`. The defaults
(`config.threads: 2`, `config.maxmemory: 512mb`) are self-consistent under a ~1Gi limit.
If you raise `config.threads`, raise `config.maxmemory` (>= threads*256MiB) and the pod
memory limit together. `config.forceEpoll` stays `true` because io_uring is restricted
under nonroot/kind/seccomp.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/dragonfly` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.enabled` | `false` | Sets `--requirepass` via a Secret. |
| `auth.password` | `""` | Generated into a Secret if empty and auth on. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `config.threads` | `2` | `--proactor_threads`. |
| `config.maxmemory` | `512mb` | `--maxmemory`. MUST be >= threads*256MiB. |
| `config.forceEpoll` | `true` | Keep epoll on (io_uring restricted under nonroot/kind). |
| `extraFlags` | `[]` | Extra dragonfly server flags (applied in `replication` mode; see note). |
| `architecture` | `standalone` | `standalone` or `replication`. |
| `sentinel.enabled` | `false` | With `replication`, adds a Sentinel quorum for automatic failover. |
| `sentinel.replicaCount` | `3` | Sentinel count. |
| `sentinel.quorum` | `2` | Sentinels that must agree the primary is down. |
| `sentinel.port` | `26379` | Sentinel port. |
| `sentinel.image.*` | valkey image | Sentinel binary source (`valkey-sentinel`), pinned by digest. |
| `busybox.*` | busybox image | Init-container helper (HA config seeding), pinned by digest. |
| `primary.replicaCount` | `1` | Primary count (keep at 1). |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/data` on the primary. |
| `replica.replicaCount` | `2` | Read replicas (replication mode). |
| `replica.persistence.enabled` | `true` | 8Gi PVC at `/data` per replica. |
| `service.port` | `6379` | RESP / Redis protocol. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by digest.

`extraFlags` take effect only in `replication` mode: there the chart runs the `dragonfly`
binary directly, whereas standalone uses the image's env-based entrypoint, which rebuilds
its own argument list and does not forward extra container args.

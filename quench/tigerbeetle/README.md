# Quenchworks TigerBeetle

Hardened [TigerBeetle](https://tigerbeetle.com) — a distributed, financial-grade
accounting database for high-throughput double-entry bookkeeping — on a minimal,
nonroot, 0-CVE image pinned by digest. This chart ships a **single-node standalone**
deployment: one `StatefulSet` replica with a PVC, a format-once `initContainer`, and
a TCP-connect readiness probe.

## Install

```bash
helm install my-tigerbeetle oci://ghcr.io/quenchworks/charts/tigerbeetle
```

## Talking to it (binary protocol, NOT HTTP)

TigerBeetle speaks its **own binary protocol** on port `3000` — it is **not** an HTTP
server, so `curl` will not work. Connect with an official
[TigerBeetle client](https://docs.tigerbeetle.com/) (Go, Java, .NET, Node, Python) or
the `tigerbeetle` CLI, pointed at the cluster id (default `0`).

```bash
kubectl port-forward svc/my-tigerbeetle 3000:3000
# then point a TigerBeetle client at 127.0.0.1:3000
```

A liveness/readiness check is a plain **TCP connect** to `:3000` (the port is open
once the server is accepting connections); the chart's probes do exactly that.

## How it runs

- **Format once**: TigerBeetle needs a formatted data file before it can start. An
  `initContainer` runs `tigerbeetle format --cluster=<cluster> --replica=0
  --replica-count=1 /data/0_0.tigerbeetle`, guarded on the file's presence so a
  restart with the PVC intact is a no-op (idempotent).
- **Start**: the main container runs `tigerbeetle start --addresses=0.0.0.0:3000
  /data/0_0.tigerbeetle`.
- **Storage**: a single PVC mounted at `/data` holds the preallocated data file
  (~1 GiB minimum; size `persistence.size` for your ledger's lifetime).

## Standalone vs replication

This chart is single-node (`replica-count 1`): no fault tolerance, one PVC. TigerBeetle
also runs as a fault-tolerant replicated cluster (replica-count 3/6 with coordinated
`--addresses`), which is a follow-up — not exposed by this chart yet. A pod or node
loss is downtime until the StatefulSet reschedules and reattaches the PVC; committed
data survives on the volume.

## io_uring

TigerBeetle performs **all** I/O through `io_uring`. The `RuntimeDefault` seccomp
profile blocks the io_uring syscalls, so the pod runs **seccomp `Unconfined`**
(`podSecurityContext.seccompProfile.type: Unconfined`). Every other hardening default
stays in force: nonroot uid 1001, read-only root filesystem, all Linux capabilities
dropped, no privilege escalation. Your cluster's kernel must have io_uring enabled
(`kernel.io_uring_disabled=0`, the default on most distros).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tigerbeetle \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/tigerbeetle --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/tigerbeetle` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `cluster` | `0` | TigerBeetle cluster id. `0` is reserved for testing — set a real id in production. |
| `cacheGrid` | `512MiB` | Grid cache size. TigerBeetle allocates all memory up front; raise this (and `resources`) for larger working sets. |
| `dataDir` | `/data` | Data file lives at `<dataDir>/0_0.tigerbeetle`. |
| `persistence.enabled` | `true` | 16Gi PVC at `/data`. |
| `persistence.size` | `16Gi` | Data file is preallocated and grows in place. |
| `service.type` | `ClusterIP` | |
| `service.port` | `3000` | TigerBeetle binary protocol (not HTTP). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal` to open it. |
| `podSecurityContext.seccompProfile.type` | `Unconfined` | Required for io_uring (see above). |
| `resources` | 500m/2Gi → 2/3Gi | Requests/limits. TigerBeetle needs ~2.5GiB at the default `cacheGrid`. |

## Memory

TigerBeetle allocates **all** its memory at startup (fixed-resource design): the grid
cache (`cacheGrid`, default `512MiB`) plus LSM manifests, message pool, and compaction
buffers. At the default that is ~2.5GiB, which fits the default 3Gi limit. Raise
`cacheGrid` and `resources.limits.memory` together for larger working sets; too small a
limit OOM-kills the pod during replica init.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped;
only the `/data` volume is writable. Seccomp is `Unconfined` (io_uring requirement).

## Notes

Replicated/HA clustering and client-facing auth are tracked as follow-ups.

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

Auth is **off by default** (matching the image — Dragonfly is open on the wire, so the
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

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dragonfly \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

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
| `extraFlags` | `[]` | Extra dragonfly server flags. |
| `replicaCount` | `1` | Single-replica StatefulSet. |
| `persistence.enabled` | `true` | 8Gi PVC at `/data`. |
| `service.port` | `6379` | RESP / Redis protocol. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by digest.

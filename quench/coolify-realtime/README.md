# Quenchworks Coolify realtime

The realtime tier of [Coolify](https://github.com/coollabsio/coolify): a
Pusher-compatible [soketi](https://soketi.app) WebSocket server (`:6001`) plus a
`node-pty` terminal bridge (`:6002`). This is the pub/sub component the Coolify UI
subscribes to for live deploy logs, resource status and the in-browser terminal.
Hardened by QuenchWorks on a minimal, nonroot, 0-CVE image built from source,
cosign-signed and pinned by digest. Licensed **AGPL-3.0-or-later** (Coolify's
license).

This chart ships the realtime component on its own. To run the full Coolify
control plane (app + realtime + PostgreSQL + Redis) use the `coolify` umbrella
chart instead.

## Install

```bash
helm install realtime oci://ghcr.io/quenchworks/charts/coolify-realtime
```

The pod runs nonroot on a read-only root filesystem. Check soketi health over a
port-forward:

```bash
kubectl port-forward svc/realtime-coolify-realtime 6001:6001
curl http://127.0.0.1:6001/ready
```

Set the soketi default-app credentials to match your Coolify app's `PUSHER_*`
values (the UI authenticates to soketi with them):

```bash
helm install realtime oci://ghcr.io/quenchworks/charts/coolify-realtime \
  --set soketi.appId=my-app-id \
  --set soketi.appKey=my-app-key \
  --set soketi.appSecret=my-app-secret
```

For production, keep the secret out of your values and source it instead:

```bash
--set extraEnvVarsSecret=my-soketi-secret   # keys: SOKETI_DEFAULT_APP_{ID,KEY,SECRET}
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/coolify-realtime \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/coolify-realtime --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/coolify-realtime` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | soketi's default adapter is in-memory (per-pod); scale beyond 1 only with an external adapter. |
| `soketi.appId` | `""` | `SOKETI_DEFAULT_APP_ID`. Empty falls back to soketi's demo app. |
| `soketi.appKey` | `""` | `SOKETI_DEFAULT_APP_KEY`. |
| `soketi.appSecret` | `""` | `SOKETI_DEFAULT_APP_SECRET`. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.soketiPort` | `6001` | Pusher-compatible WebSocket / HTTP. |
| `service.terminalPort` | `6002` | node-pty terminal bridge. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | |
| `networkPolicy.enabled` | `true` | Restricts ingress to the two ports. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A Deployment runs the image's shell entrypoint, which launches soketi bound to
`0.0.0.0:6001` (from `SOKETI_HOST` / `SOKETI_PORT`) and the node-pty terminal
server on `:6002`; the Service maps both named ports. soketi's default app is
configured from `SOKETI_DEFAULT_APP_{ID,KEY,SECRET}`. Liveness `httpGet /` and
readiness `httpGet /ready` both hit the soketi port (200 once it is up). The
container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped; the only writable surfaces are two emptyDir mounts — `/tmp`
(the entrypoint writes log FIFOs there) and `/home/coolify` (node-pty spawns its
PTY with `cwd=$HOME`).

## Uninstall

```bash
helm uninstall realtime
```

Nothing persists — the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. soketi's default in-memory
adapter is per-pod, so multi-replica pub/sub requires an external (Redis) adapter
configured through `extraEnvVars`. Keep the NetworkPolicy as the trust boundary
before exposing the realtime tier beyond the cluster.

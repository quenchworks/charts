# Quenchworks ntfy

Hardened [ntfy](https://github.com/binwiederhier/ntfy) — a simple pub/sub HTTP
notification server that publishes and subscribes to notifications over plain
HTTP — on a minimal, nonroot, 0-CVE image, rebuilt from source and pinned by
digest. It runs as a stateless Deployment on a read-only root filesystem with all
capabilities dropped. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

```bash
helm install ntfy oci://ghcr.io/quenchworks/charts/ntfy
```

The server runs nonroot and serves HTTP on container port 8080; the Service
exposes it on the same port. Check health and publish a message over a
port-forward:

```bash
kubectl port-forward svc/ntfy 8080:8080
curl http://127.0.0.1:8080/v1/health      # -> {"healthy":true}
curl -d "hello" http://127.0.0.1:8080/mytopic
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ntfy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/ntfy --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ntfy` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment. Keep at 1 with an on-disk cache (single writer). |
| `config.yaml` | `""` | Inline ntfy server config (base-url, auth, cache-file, ...); written to a ConfigMap, mounted at `/etc/ntfy/server.yml`, passed via `--config`. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `server.yml`) instead; wins over `config.yaml`. |
| `extraArgs` | `[]` | Extra flags appended to the `ntfy serve` command. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | HTTP API; also the container listen port. |
| `persistence.enabled` | `false` | `false` = ephemeral `emptyDir`; `true` = PVC at `persistence.mountPath`. |
| `persistence.mountPath` | `/var/cache/ntfy` | Writable cache/attachment dir. |
| `persistence.size` | `1Gi` | PVC size when enabled. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `autoscaling.enabled` | `false` | HPA on CPU (only meaningful for the in-memory/stateless mode). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress on the HTTP port. |
| `networkPolicy.allowExternal` | `true` | ntfy is usually published to clients across the cluster; set `false` to restrict to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

ntfy is a single stateless Go binary running as `ntfy serve --listen-http :8080`
behind a ClusterIP Service. With the default config it keeps message state in
memory with no authentication, so the workload can scale horizontally.

The runtime image has a read-only root filesystem, so a writable cache dir is
always mounted at `persistence.mountPath` — an ephemeral `emptyDir` by default.
Set `persistence.enabled=true` to back it with a PersistentVolumeClaim, and point
`config.yaml`'s `cache-file` / `attachment-cache-dir` under that path to persist
the message cache and attachments across restarts (keep `replicaCount` at 1 for a
single writer to the store). The container runs nonroot with all capabilities
dropped.

## Configuration examples

Persist the message cache and attachments on a PVC, behind a reverse proxy:

```yaml
persistence:
  enabled: true
  size: 5Gi
config:
  yaml: |
    base-url: https://ntfy.example.com
    behind-proxy: true
    cache-file: /var/cache/ntfy/cache.db
    attachment-cache-dir: /var/cache/ntfy/attachments
```

Point at an externally-managed ConfigMap instead (key `server.yml`):

```yaml
config:
  existingConfigMap: my-ntfy-config
```

## Uninstall

```bash
helm uninstall ntfy
```

When `persistence.enabled=true`, the PVC is retained by Kubernetes on uninstall —
delete it explicitly if you want the cached data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=ntfy
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on
a read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. ntfy runs with no authentication by default — configure `auth-*` in
`config.yaml` and keep the NetworkPolicy as the trust boundary before exposing it
beyond the cluster.

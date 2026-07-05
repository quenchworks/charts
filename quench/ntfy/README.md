# Quenchworks ntfy

Hardened [ntfy](https://github.com/binwiederhier/ntfy) on a minimal, nonroot,
0-CVE image, rebuilt from source and pinned by digest. ntfy is a simple pub/sub
HTTP notification server: publish and subscribe to notifications with plain HTTP.

## Install

```sh
helm install ntfy oci://ghcr.io/quenchworks/charts/ntfy
```

The server runs nonroot and serves HTTP on container port 8080; the Service
exposes it on the same port. Check health and publish a message over a
port-forward:

```sh
kubectl port-forward svc/ntfy 8080:8080
curl http://127.0.0.1:8080/v1/health      # -> {"healthy":true}
curl -d "hello" http://127.0.0.1:8080/mytopic
```

## Configuration

ntfy runs as `ntfy serve --listen-http :8080`. By default it keeps message state
in memory with no authentication. Set `config.yaml` to a full ntfy server config
(base-url, behind-proxy, auth-*, cache-file, attachment-cache-dir, ...); it is
written to a ConfigMap, mounted at `/etc/ntfy/server.yml`, and passed via
`--config`. Point `config.existingConfigMap` at an externally-managed ConfigMap
(key `server.yml`) to use that instead.

The runtime image has a read-only root filesystem, so a writable cache dir is
always mounted at `persistence.mountPath` (an ephemeral `emptyDir` by default).
Set `persistence.enabled=true` to back it with a PersistentVolumeClaim, and point
`config.yaml`'s `cache-file` / `attachment-cache-dir` under that path to persist
the message cache and attachments across restarts.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ntfy` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `config.yaml` | `""` | inline ntfy server config (mounted, passed via `--config`) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `server.yml`, wins) |
| `extraArgs` | `[]` | appended to the `ntfy serve` command |
| `service.type` | `ClusterIP` | |
| `service.port` | `8080` | HTTP API; also the container listen port |
| `persistence.enabled` | `false` | `false` = emptyDir, `true` = PVC at `persistence.mountPath` |
| `persistence.mountPath` | `/var/cache/ntfy` | writable cache/attachment dir |
| `persistence.size` | `1Gi` | PVC size when enabled |
| `networkPolicy.enabled` | `true` | ingress on the HTTP port |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` |

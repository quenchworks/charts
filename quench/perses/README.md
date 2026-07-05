# Quenchworks Perses

Hardened [Perses](https://github.com/perses/perses), the CNCF open dashboard and
observability visualization tool, on a minimal, nonroot, 0-CVE image, built from
source and pinned by digest.

## Install

```sh
helm install dash oci://ghcr.io/quenchworks/charts/perses
```

The server runs nonroot and serves the UI and API on container port 8080; the
Service exposes it on the same port. Open the UI and check health over a
port-forward:

```sh
kubectl port-forward svc/dash-perses 8080:8080
# UI:     http://127.0.0.1:8080/
# Health: http://127.0.0.1:8080/api/v1/health
```

## Configuration

The container entrypoint is `perses --config=/etc/perses/config.yaml`. The image
ships a minimal config that uses a file datastore (no external database), so the
chart boots with sane defaults out of the box. Append flags with `extraArgs`, or
mount your own config via `extraVolumes`/`extraVolumeMounts`.

Perses runs on a read-only root filesystem and writes to two locations, both
backed by writable volumes the chart mounts automatically:

- the file datastore at `/perses` (dashboards, projects) — controlled by
  `persistence` below;
- the plugin cache at `/etc/perses/plugins`, where the bundled plugin archives
  are unpacked on boot — an always-on ephemeral `emptyDir`.

### Persistence

By default the datastore uses an `emptyDir`, so dashboards and projects are lost
on pod restart. Enable `persistence` for a PersistentVolumeClaim to keep them:

```sh
helm install dash oci://ghcr.io/quenchworks/charts/perses \
  --set persistence.enabled=true --set persistence.size=8Gi
```

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/perses` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | file datastore is per-pod; scale only with a shared backend |
| `extraArgs` | `[]` | appended to the `perses` command |
| `persistence.enabled` | `false` | PVC-backed datastore (else ephemeral `emptyDir`) |
| `persistence.path` | `/perses` | datastore folder (matches the perses config) |
| `persistence.size` | `8Gi` | PVC size when enabled |
| `persistence.existingClaim` | `""` | use an externally-managed PVC |
| `service.type` | `ClusterIP` | |
| `service.port` | `8080` | UI and API |

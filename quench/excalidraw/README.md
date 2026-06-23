# Quenchworks Excalidraw

Hardened, self-hosted [Excalidraw](https://github.com/excalidraw/excalidraw)
virtual whiteboard, served as a static SPA by nginx on a minimal, nonroot,
0-CVE image, built from source and pinned by digest.

## Install

```sh
helm install board oci://ghcr.io/quenchworks/charts/excalidraw
```

nginx serves the app nonroot on container port 8080; the Service exposes HTTP 80.
Open it over a port-forward:

```sh
kubectl port-forward svc/board-excalidraw 8080:80
# visit http://127.0.0.1:8080
```

This is the static, no-backend build of Excalidraw: drawings stay in the browser
(local storage), and there is no account or server-side storage. The container
runs on a read-only root filesystem with a writable tmpfs only at `/tmp` for
nginx. Expose it outside the cluster with your own Ingress or LoadBalancer.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/excalidraw` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `service.type` | `ClusterIP` | |
| `service.port` | `80` | Service maps 80 -> container 8080 |

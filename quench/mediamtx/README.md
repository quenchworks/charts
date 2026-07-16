# Quenchworks MediaMTX

Hardened [MediaMTX](https://github.com/bluenviron/mediamtx) — a zero-dependency
real-time media server that ingests and republishes streams over RTSP, RTMP, HLS,
WebRTC and SRT — on a minimal, nonroot, 0-CVE image, built from source and pinned
by digest. It runs as a stateless Deployment on a read-only root filesystem with
all capabilities dropped. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

```bash
helm install stream oci://ghcr.io/quenchworks/charts/mediamtx
```

The server runs nonroot on MediaMTX's baked defaults: RTSP `:8554`, RTMP `:1935`,
HLS `:8888`, WebRTC `:8889`, all exposed on the Service. No configuration is
required — MediaMTX boots on a config baked into the image and fills any unset key
from its compiled-in defaults.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mediamtx \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/mediamtx --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mediamtx` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `api.enabled` | `false` | Enable the control API `:9997` (injects a minimal config) and expose it on the Service. |
| `api.port` | `9997` | Control API port. |
| `config.yaml` | `""` | Full MediaMTX config; written to a ConfigMap, mounted at `/config/mediamtx.yml`, passed to the server. Wins over `api`. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `mediamtx.yml`) instead; wins over `config.yaml`. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.ports.rtsp` | `8554` | RTSP listen port. |
| `service.ports.rtmp` | `1935` | RTMP listen port. |
| `service.ports.hls` | `8888` | HLS listen port. |
| `service.ports.webrtc` | `8889` | WebRTC listen port. |
| `autoscaling.enabled` | `false` | HPA on CPU. |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Streaming ports are usually reached across the cluster; set `false` to restrict to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs MediaMTX behind a ClusterIP Service that maps the four
streaming ports (RTSP `8554`, RTMP `1935`, HLS `8888`, WebRTC `8889`). MediaMTX
holds no persistent state by default — HLS is in-memory and no recordings are
written — so the workload scales horizontally; enable `autoscaling` (HPA on CPU)
or raise `replicaCount`.

Liveness and readiness are a **TCP check on the RTSP port** (`:8554`). The listener
comes up as soon as the server is ready and needs no auth. The control API is a
poor probe target because MediaMTX's default auth only accepts unauthenticated API
calls from localhost, which off-pod kubelet probes are not.

The **control API** (`:9997`) is off by default. Set `api.enabled=true` to inject a
minimal config that turns it on and expose the port on the Service. Its default
auth still only allows unauthenticated access from localhost, so a
`kubectl port-forward` works (it arrives over the pod loopback), but add your own
auth (`authInternalUsers` / `authHTTPAddress` via `config.yaml`) before relying on
the API off-pod:

```sh
kubectl port-forward svc/stream-mediamtx 9997:9997
curl http://127.0.0.1:9997/v3/config/global/get
```

The container runs nonroot on a read-only root filesystem with all capabilities
dropped.

## Configuration examples

Take full control of the server by supplying a complete MediaMTX config. When
`config.yaml` (or `config.existingConfigMap`) is set you own the whole config and
the API snippet is not injected:

```yaml
config:
  yaml: |
    api: yes
    apiAddress: :9997
    paths:
      cam:
        source: rtsp://camera.example.com:554/stream
```

Point at an externally-managed ConfigMap instead (key `mediamtx.yml`):

```yaml
config:
  existingConfigMap: my-mediamtx-config
```

## Uninstall

```bash
helm uninstall stream
```

Nothing persists — the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on
a read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. MediaMTX serves streams without authentication by default — configure
authentication in `config.yaml` and keep the NetworkPolicy as the trust boundary
before exposing it beyond the cluster.

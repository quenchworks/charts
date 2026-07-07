# Quenchworks MediaMTX

Hardened [MediaMTX](https://github.com/bluenviron/mediamtx) on a minimal, nonroot,
0-CVE image, built from source and pinned by digest. MediaMTX is a zero-dependency
real-time media server that ingests and republishes streams over RTSP, RTMP, HLS,
WebRTC and SRT.

## Install

```sh
helm install stream oci://ghcr.io/quenchworks/charts/mediamtx
```

The server runs nonroot on MediaMTX's baked defaults: RTSP `:8554`, RTMP `:1935`,
HLS `:8888`, WebRTC `:8889`, all exposed on the Service.

## Health

Liveness/readiness are a TCP check on the RTSP port (`:8554`) — the listener comes
up as soon as the server is ready and needs no auth. The control API is a poor
probe target because MediaMTX's default auth only accepts unauthenticated API
calls from localhost, which off-pod kubelet probes are not.

## Control API

The control API (`:9997`) is off by default. Enable it with `--set api.enabled=true`
to inject a minimal config and expose the port on the Service. Its default auth
still only allows unauthenticated access from localhost, so a `kubectl port-forward`
works (it arrives over the pod loopback):

```sh
kubectl port-forward svc/stream-mediamtx 9997:9997
curl http://127.0.0.1:9997/v3/config/global/get
```

Add your own auth (`authInternalUsers` / `authHTTPAddress` via `config.yaml`)
before relying on the API off-pod.

## Configuration

MediaMTX boots on a config baked into the image and fills any unset key from its
compiled-in defaults, so no configuration is required. This chart mounts a minimal
generated config that only enables the control API. To take full control, set
`config.yaml` to a complete MediaMTX config (written to a ConfigMap, mounted at
`/config/mediamtx.yml` and passed to the server), or point
`config.existingConfigMap` at a ConfigMap carrying key `mediamtx.yml`. When either
is set you own the whole config and the API snippet is not injected.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mediamtx` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `api.enabled` | `false` | expose control API `:9997` (localhost-authed by default) |
| `api.port` | `9997` | control API port |
| `config.yaml` | `""` | full MediaMTX config override (mounted, wins over `api`) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `mediamtx.yml`, wins) |
| `service.type` | `ClusterIP` | |
| `service.ports.rtsp` | `8554` | RTSP |
| `service.ports.rtmp` | `1935` | RTMP |
| `service.ports.hls` | `8888` | HLS |
| `service.ports.webrtc` | `8889` | WebRTC |

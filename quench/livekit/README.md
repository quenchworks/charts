# Quenchworks LiveKit

Hardened [LiveKit](https://github.com/livekit/livekit) WebRTC SFU on a minimal,
nonroot, 0-CVE image, built from source and pinned by digest. This chart runs a
**single-node** server (no Redis) suited to dev and small deployments.

## Install

```sh
helm install rtc oci://ghcr.io/quenchworks/charts/livekit
```

The server runs nonroot and serves HTTP/WebSocket signaling + health on container
port 7880, with an RTC/TCP fallback on 7881; the Service exposes both. Check
health over a port-forward (`GET /` returns 200 `OK`):

```sh
kubectl port-forward svc/rtc-livekit 7880:7880
curl http://127.0.0.1:7880/
```

## Configuration

LiveKit runs as `livekit-server --config /config/config.yaml` and **requires** a
config with at least one API key pair. This chart ships a working single-node
default in `config.yaml`; it is written to a ConfigMap, mounted at
`/config/config.yaml`, and passed via `--config`. Point `config.existingConfigMap`
at an externally-managed ConfigMap (key `config.yaml`) to use that instead.

> **Rotate the dev keys.** The default `config.yaml` carries a **fixed dev API key
> pair** so the server boots deterministically. Generate a fresh pair with
> `livekit-server generate-keys` and override `config.yaml`, or drop `keys` from
> the config and inject `LIVEKIT_KEYS` from a Secret via `extraEnvVarsSecret`.

### Single-node vs. production

This chart is single-node: no Redis, and WebRTC media UDP is **not** surfaced on
the ClusterIP Service. For production, add Redis for multi-node routing and expose
the RTC UDP port range (plus TCP 7881 / a TURN server) through a LoadBalancer or
host networking so clients can reach media. See the
[LiveKit deployment docs](https://docs.livekit.io/home/self-hosting/deployment/).

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/livekit` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | single-node; scale needs Redis |
| `config.yaml` | (single-node default) | inline LiveKit config, mounted + `--config` |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `config.yaml`, wins) |
| `extraArgs` | `[]` | appended to `livekit-server` |
| `service.type` | `ClusterIP` | |
| `service.port` | `7880` | HTTP/WS signaling + health |
| `service.rtcTcpPort` | `7881` | RTC over TCP fallback |

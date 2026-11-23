# PairDrop

[PairDrop](https://pairdrop.net), local file sharing in the browser (an AirDrop alternative): devices on the same
network, paired devices or public rooms exchange files and text peer to peer over WebRTC, with this Node server doing
the signaling. The image is built from source by QuenchWorks, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install pairdrop oci://ghcr.io/quenchworks/charts/pairdrop
```

Browsers require HTTPS for WebRTC: put an Ingress with TLS in front (WebSocket upgrades must pass through).

## Values

| Key | Default | Meaning |
|---|---|---|
| `rtcConfig` | `{}` | WebRTC configuration (STUN/TURN `iceServers`) sent to browsers; mounted as `RTC_CONFIG`. |
| `rateLimit` | `false` | Limit connections per client IP (the proxy hop count behind an Ingress). |
| `wsFallback` | `false` | Relay transfers through the server when WebRTC cannot connect. |
| `settings` | `{}` | Other PairDrop environment settings (footer button links, `DEBUG_MODE`). |

One replica: rooms and peers live in memory.

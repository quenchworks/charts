# LibreSpeed

[LibreSpeed](https://librespeed.org), a self-hosted network speed test (download, upload, ping, jitter) with a web UI:
the Go backend speedtest-go with the frontend embedded. The image is built from source by QuenchWorks, CVE-gated,
signed with cosign and pinned by digest.

## Install

```sh
helm install speedtest oci://ghcr.io/quenchworks/charts/librespeed
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `telemetry.enabled` | `false` | Keep each result (sqlite on a volume) and enable `/stats` behind a generated password. |
| `telemetry.redactIpAddresses` | `false` | Drop client IPs from stored results. |
| `server.latitude`, `.longitude` | `0` | The server's location. |
| `ipinfoApiKey` | `""` | ipinfo.io key for ISP details in results. |
| `replicaCount` | `1` | Scale out without telemetry (stateless); one replica with it. |

The settings file is rendered into a Secret (it holds the stats password) and mounted read-only.

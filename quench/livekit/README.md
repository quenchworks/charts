# Quenchworks LiveKit

Hardened [LiveKit](https://github.com/livekit/livekit) WebRTC SFU on a minimal,
nonroot, 0-CVE image, built from source, cosign-signed and pinned by digest. This
chart runs a single-node server (no Redis) suited to dev and small deployments.
The container runs nonroot on a read-only root filesystem with all capabilities
dropped.

## Install

```sh
helm install rtc oci://ghcr.io/quenchworks/charts/livekit
```

The server serves HTTP/WebSocket signaling and health on container port `7880`,
with an RTC/TCP fallback on `7881`; the Service exposes both. Check health over a
port-forward (`GET /` returns 200 `OK`):

```sh
kubectl port-forward svc/rtc-livekit 7880:7880
curl http://127.0.0.1:7880/
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/livekit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```sh
gh attestation verify oci://ghcr.io/quenchworks/images/livekit --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/livekit` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single-node; scaling beyond 1 needs Redis. |
| `config.yaml` | (single-node default) | Inline LiveKit config. Written to a ConfigMap, mounted at `/config/config.yaml`, passed via `--config`. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `config.yaml`) instead; wins over `config.yaml`. |
| `extraArgs` | `[]` | Extra flags appended to `livekit-server`. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `7880` | HTTP/WS signaling + health. |
| `service.rtcTcpPort` | `7881` | RTC over TCP fallback. |
| `autoscaling.enabled` | `false` | HPA on CPU. Leave off for single-node (scaling needs Redis). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A Deployment runs `livekit-server --config /config/config.yaml` behind a Service.
LiveKit requires a config with at least one API key pair, so the chart ships a
working single-node default in `config.yaml`; it renders to a ConfigMap mounted
read-only at `/config` and appended to the command as `--config`, with `extraArgs`
after that. Liveness and readiness `httpGet /` on the signaling port.

This chart is single-node: no Redis, and WebRTC media UDP is not surfaced on the
ClusterIP Service, so single-node dev exercises signaling only. For production,
add Redis for multi-node routing and expose the RTC UDP port range (plus TCP 7881
or a TURN server) through a LoadBalancer or host networking so clients can reach
media. See the
[LiveKit deployment docs](https://docs.livekit.io/home/self-hosting/deployment/).

## Configuration examples

> Rotate the dev keys. The default `config.yaml` carries a fixed dev API key pair
> so the server boots deterministically. In production, generate a fresh pair with
> `livekit-server generate-keys` and override `config.yaml`, or drop `keys` from
> the config and inject `LIVEKIT_KEYS` from a Secret via `extraEnvVarsSecret`.

Bring your own keys and widen the RTC UDP range:

```yaml
config:
  yaml: |
    port: 7880
    rtc:
      tcp_port: 7881
      port_range_start: 50000
      port_range_end: 60000
      use_external_ip: true
    keys:
      APIxxxxxxxx: <generated-secret>
    logging:
      level: info
```

Inject keys from a Secret instead of the config:

```yaml
config:
  yaml: |
    port: 7880
    logging:
      level: info
extraEnvVarsSecret: livekit-keys   # supplies LIVEKIT_KEYS
```

## Uninstall

```sh
helm uninstall rtc
```

The workload is stateless and holds no PVCs.

## Notes

The single-node topology (no Redis, signaling-only media) fits dev and small
deployments. Multi-node routing (Redis) and external media (RTC UDP + TURN) are
configured yourself for production. The chart depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. The
container runs as nonroot on a read-only root filesystem with all capabilities
dropped, and the image is pinned by digest.

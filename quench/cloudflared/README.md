# Quenchworks cloudflared

Hardened [cloudflared](https://github.com/cloudflare/cloudflared), the Cloudflare Tunnel client.
It dials out to Cloudflare and carries traffic for the public hostnames of a tunnel to services in
the cluster, so nothing needs an inbound port, a LoadBalancer or a public IP.

The image is built from the upstream release tag as one static Go binary (with upstream's
container metrics stamp), runs as nonroot uid 1001 with auto-update off, is CVE-gated (the build
fails on any fixable CVE), and is cosign-signed and pinned by digest.

## Install

Create a tunnel in the Cloudflare dashboard (Zero Trust > Networks > Tunnels), copy its token, and:

```bash
kubectl create secret generic tunnel --from-literal=token=<TUNNEL_TOKEN>
helm install edge oci://ghcr.io/quenchworks/charts/cloudflared --set tunnel.existingSecret=tunnel
```

Then add public hostnames on the tunnel in the dashboard, pointing at in-cluster Services, e.g.
`app.example.com` to `http://my-app.default.svc:80`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cloudflared \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/cloudflared@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/cloudflared` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `2` | Cloudflare balances a tunnel across every connected replica. |
| `tunnel.token` | `""` | Tunnel token, stored in the chart's Secret (prefer `existingSecret`). |
| `tunnel.existingSecret` / `existingSecretKey` | `""` / `token` | Secret holding the token. |
| `tunnel.protocol` | `auto` | `auto`, `quic` or `http2` (`http2` where UDP egress is blocked). |
| `tunnel.logLevel` | `info` | |
| `extraArgs` | `[]` | Extra `cloudflared tunnel` flags. |
| `metrics.port` | `2000` | `/metrics`, `/ready` (connected), Service `<release>-cloudflared-metrics`. |
| `networkPolicy.enabled` / `allowExternal` | `true` / `false` | Ingress to the metrics port only. |
| `podDisruptionBudget.enabled` / `minAvailable` | `true` / `1` | Keep one connector during node drains. |
| `resources` | 25m / 64Mi requests, 1 CPU / 256Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **No listener but metrics, so no TLS block.** cloudflared dials out to Cloudflare over QUIC or
  HTTP/2 with Cloudflare's certificates; it serves nothing in the cluster but `/metrics`.
- **The token stays out of the process list.** It reaches cloudflared as `TUNNEL_TOKEN` from a
  Secret, not as a flag.
- **Readiness is the edge connection** (`/ready`); liveness reads `/metrics`.
- **Auto-update is off**: update by moving the chart to a new image digest.

cloudflared is Apache-2.0 licensed.

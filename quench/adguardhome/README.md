# Quenchworks AdGuard Home

Hardened [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome), a network-wide ad and tracker
blocking DNS server with a web UI, encrypted upstreams (DNS-over-HTTPS, TLS and QUIC), blocklists and
per-client rules. The image is built from source with its web client embedded; it runs as uid 1001 and
is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/adguardhome --set service.type=LoadBalancer
kubectl get secret dns-adguardhome -o jsonpath='{.data.admin-password}' | base64 -d
```

The chart seeds a config with the admin (as a bcrypt hash) and DNS on port 5353 in the pod, so the setup
wizard is skipped and the pod needs no privileged port; the Service publishes DNS on 53 (UDP and TCP).
The seed is copied on the first start only: after that AdGuard owns its config file on the volume, and
settings you change in the UI persist.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The web UI admin (password generated into the Secret) |
| `admin.existingSecret` | `""` | A Secret with `admin-password` and your own seed `AdGuardHome.yaml` |
| `upstreamDNS` | `[]` | Upstream servers for the seed config; empty keeps AdGuard's defaults |
| `service.type` | `ClusterIP` | `LoadBalancer` to serve DNS to your network |
| `service.port`, `service.dnsPort` | `3000`, `53` | Web UI and DNS |
| `persistence.size` | `5Gi` | Config, query log, statistics and filter lists |

AdGuard Home's own TLS (HTTPS UI, DoH and DoT for clients) is not wired by this chart yet; put the web
UI behind an ingress with TLS.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/adguardhome \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

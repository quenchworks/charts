# Quenchworks wstunnel

Hardened [wstunnel](https://github.com/erebe/wstunnel) server: tunnels TCP, UDP, SOCKS5 and stdio over
WebSocket or HTTP/2, so clients behind restrictive proxies and firewalls can reach services. The image is
built from source with cargo auditable and the ring crypto provider; it runs as uid 1001 and is CVE-gated
at build, cosign-signed and pinned by digest. The same image is the client.

## Install

```bash
helm install tunnel oci://ghcr.io/quenchworks/charts/wstunnel \
  --set 'restrictTo={db.internal:5432}' --set tls.enabled=true
kubectl get secret tunnel-wstunnel -o jsonpath='{.data.path-prefix}' | base64 -d
wstunnel client -L tcp://5432:db.internal:5432 --http-upgrade-path-prefix <prefix> wss://tunnel.example.com
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `pathPrefix.enabled` | `true` | Clients must send the generated prefix (`--restrict-http-upgrade-path-prefix`) |
| `pathPrefix.existingSecret` | `""` | A Secret with key `path-prefix` |
| `restrictTo` | `[]` | Allowed targets (`host:port`); empty allows any target, so set it |
| `extraArgs` | `[]` | More server flags (`--restrict-config`, log level) |
| `replicaCount` | `2` | Stateless replicas |
| `tls.enabled` | `false` | `wss://` on 8080 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/wstunnel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

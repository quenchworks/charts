# Quenchworks Chhoto URL

Hardened [Chhoto URL](https://github.com/SinTan1729/chhoto-url): a small self-hosted URL shortener with a web UI, API
keys, expiring links, hit counts and OIDC login, on SQLite. The image is built from source with cargo auditable (so
scanners see every crate); it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install links oci://ghcr.io/quenchworks/charts/chhoto-url --set siteUrl=https://s.example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=s.example.com' \
  --set 'ingress.tls[0].hosts[0]=s.example.com' --set 'ingress.tls[0].secretName=s-example-tls'
kubectl get secret links-chhoto-url -o jsonpath='{.data.password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.password`, `auth.apiKey` | generated | Web UI password and API key (64 random bytes, base64url), kept on upgrade |
| `auth.existingSecret` | `""` | A Secret with keys `password` and `api-key` instead |
| `siteUrl` | `""` | Public base URL for short links |
| `settings` | `{}` | More `CHHOTO_*` settings (slug style, public mode, OIDC, custom title) |
| `persistence.size` | `1Gi` | The SQLite database (`/var/lib/chhoto-url`) |
| `ingress.*` | off | Chhoto URL has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/chhoto-url \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

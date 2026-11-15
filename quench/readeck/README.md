# Quenchworks Readeck

Hardened [Readeck](https://readeck.org), a read-it-later and bookmark manager: it saves the full text
and images of articles, with highlights, labels, collections and e-book export, and works with its
browser extension and mobile apps. The image is built from source and linked to Wolfi's SQLite; it runs
as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install read oci://ghcr.io/quenchworks/charts/readeck --set baseURL=https://read.example.com
kubectl get secret read-readeck -o jsonpath='{.data.password}' | base64 -d   # user admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email` | `admin`, `admin@example.com` | The admin the chart creates and keeps in step with the Secret |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `baseURL` | `""` | The public URL (`READECK_SERVER_BASE_URL`) |
| `allowedHosts`, `trustedProxies` | `[]` | Host names to answer, proxies to trust |
| `settings` | `{}` | More `READECK_*` variables (mail, OIDC, workers) |
| `persistence.size` | `5Gi` | config.toml, the database and saved articles |
| `tls.enabled` | `false` | HTTPS on 8000 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/readeck \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

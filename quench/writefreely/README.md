# Quenchworks WriteFreely

Hardened [WriteFreely](https://writefreely.org), a minimalist publishing platform: Markdown blogs that
federate over ActivityPub, collections, a reader, and a Write.as-compatible API. The image is built
from source and linked to Wolfi's SQLite; it runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest.

## Install

```bash
helm install blog oci://ghcr.io/quenchworks/charts/writefreely --set host=https://blog.example.com
kubectl get secret blog-writefreely -o jsonpath='{.data.password}' | base64 -d   # user admin
```

WriteFreely's own TLS listener needs port 443, which a nonroot pod cannot bind, so put an ingress with
TLS in front. The admin is created once, when the database first exists; change its password in the UI.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `host` | required | The public URL |
| `siteName`, `siteDescription` | `WriteFreely`, `""` | Shown on the site |
| `admin.username` | `admin` | The admin the chart creates |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `singleUser`, `openRegistration`, `maxBlogs` | `false`, `false`, `1` | Who can blog |
| `federation`, `private`, `localTimeline` | `true`, `false`, `false` | ActivityPub, sign-in to read, Reader page |
| `extraConfig` | `""` | More config.ini sections (email, OAuth) |
| `persistence.size` | `5Gi` | SQLite and keys |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/writefreely \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

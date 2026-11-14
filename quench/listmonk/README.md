# Quenchworks listmonk

Hardened [listmonk](https://github.com/knadh/listmonk), a self-hosted newsletter and mailing-list
manager: campaigns, templates, subscriber lists, analytics and an API. The image is one CGO-free
Go binary built from source with the yarn-built admin UI packed in, runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install news oci://ghcr.io/quenchworks/charts/listmonk
kubectl get secret news-listmonk -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/news-listmonk 9000
```

Log in as `admin` at `http://localhost:9000/admin`, then set the root URL, SMTP and the media
provider under Settings (listmonk keeps them in the database).

## How it starts

Before the server, two init containers run the same image: `--install --idempotent --yes`
creates the schema and the first admin on an empty database (a no-op afterwards), and
`--upgrade --yes` applies the migrations of a newer listmonk. Both read the database settings
from `LISTMONK_db__*`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.password` | `admin`, generated | First admin, created by the install step on an empty database |
| `postgresql.enabled` | `true` | Bundled PostgreSQL; set `false` and fill `externalDatabase.*` for your own |
| `settings` | `{}` | Extra `LISTMONK_*` env (TOML keys, `__` for nesting) |
| `persistence.size` | `2Gi` | Media uploads (filesystem provider) |
| `ingress.enabled` | `false` | Ingress to the HTTP port |

## Image uploads and CVE-2023-36308

listmonk thumbnails uploaded images with `disintegration/imaging` 1.6.2, which has no fixed
release for CVE-2023-36308. The image floors `golang.org/x/image` at a release whose decoders
reject the crafted palettes that trigger it and patches imaging's palette table at build time;
the image's VEX statement records the evidence.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/listmonk \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

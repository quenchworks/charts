# Quenchworks Shiori

Hardened [Shiori](https://github.com/go-shiori/shiori), a bookmark manager with readable offline
archives, a web UI, a REST API and a CLI. The image is one CGO-free Go binary built from source,
runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install marks oci://ghcr.io/quenchworks/charts/shiori
kubectl get secret marks-shiori-owner -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/marks-shiori 8080
```

Log in as `shiori` at `http://localhost:8080`. Upstream creates `shiori` / `gopher` on the first
start; this image reads the first owner from `SHIORI_INITIAL_USERNAME` / `SHIORI_INITIAL_PASSWORD`
instead, and the chart fills them from a generated Secret.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `owner.username`, `owner.password` | `shiori`, generated | First owner, created on the first start only |
| `database.existingSecret` | `""` (SQLite) | Secret holding a full `SHIORI_DATABASE_URL` for PostgreSQL or MySQL (key `database.urlKey`) |
| `settings` | `{}` | Shiori options as env (`SHIORI_HTTP_ROOT_PATH`, `SHIORI_SSO_PROXY_AUTH_ENABLED`, ...) |
| `persistence.size` | `2Gi` | Data volume: SQLite, archives, thumbnails |

The session signing key (`SHIORI_HTTP_SECRET_KEY`) is generated into `<release>-shiori-session`
and kept across upgrades, so restarts do not log users out. One replica: the data volume is
ReadWriteOnce and the Deployment uses Recreate.

## Thumbnails and CVE-2023-36308

Shiori resizes bookmark thumbnails with `disintegration/imaging` 1.6.2, which has no fixed release
for CVE-2023-36308. The image floors `golang.org/x/image` at a release whose decoders reject the
crafted palettes that trigger it and patches imaging's palette table at build time; the image's
VEX statement records the evidence.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/shiori \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

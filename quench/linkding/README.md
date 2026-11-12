# Quenchworks linkding

Hardened [linkding](https://github.com/sissbruecker/linkding), a self-hosted bookmark manager:
tags, full-text search, read-later, archived snapshots, a REST API and browser extensions. The
image is built from source (Django in a venv on Wolfi Python, npm-built frontend), runs as uid
1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install links oci://ghcr.io/quenchworks/charts/linkding
kubectl get secret links-linkding-superuser -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/links-linkding 9090
```

Log in as `admin` at `http://localhost:9090`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `superuser.username`, `superuser.password` | `admin`, generated | Initial admin, created on first start |
| `database.engine` | `sqlite` | `postgres` with `host`, `name`, `user`, `existingSecret` |
| `settings` | `{}` | linkding options as env (`LD_CSRF_TRUSTED_ORIGINS`, `LD_ENABLE_OIDC`, ...) |
| `persistence.size` | `2Gi` | Data volume: SQLite, favicons, previews, assets |

One replica: the data volume is ReadWriteOnce and the Deployment uses Recreate.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/linkding \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

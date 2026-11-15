# Quenchworks Opengist

Hardened [Opengist](https://github.com/thomiceli/opengist), a self-hosted pastebin backed by Git:
a web UI, search, OAuth sign-in, and gists you push and clone with git over HTTP and SSH. The
image is one CGO-free Go binary built from source with the frontend embedded, plus git; it runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install gists oci://ghcr.io/quenchworks/charts/opengist
kubectl get secret gists-opengist-admin -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/gists-opengist 6157
```

Upstream makes the first account that signs up the admin. This chart seeds the admin before the
server starts (an init container runs `opengist admin create-user --admin`, a no-op once the user
exists), so a fresh install has no open admin sign-up.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.password` | `admin`, generated | Seeded admin account |
| `database.existingSecret` | `""` (SQLite) | Secret holding `OG_DB_URI` for PostgreSQL or MySQL (key `database.uriKey`) |
| `ssh.enabled`, `ssh.servicePort` | `true`, `2222` | Git over SSH |
| `settings` | `{}` | More `OG_*` env (`OG_EXTERNAL_URL`, OAuth, ...) |
| `persistence.size` | `5Gi` | Database, repositories, SSH host key |

One replica: the data volume is ReadWriteOnce and the Deployment uses Recreate.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/opengist \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

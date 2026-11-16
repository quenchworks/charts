# Quenchworks flatnotes

Hardened [flatnotes](https://github.com/dullage/flatnotes): a database-less Markdown note app on a plain folder of
files, with full-text search, tags, wikilinks and password or TOTP auth. The image builds the Vue client and the
FastAPI server from source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install notes oci://ghcr.io/quenchworks/charts/flatnotes \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=flatnotes.example.com' \
  --set 'ingress.tls[0].hosts[0]=flatnotes.example.com' --set 'ingress.tls[0].secretName=flatnotes-tls'
kubectl get secret notes-flatnotes -o jsonpath='{.data.password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.type` | `password` | `password`, `totp`, `read_only` or `none` |
| `auth.username`, `auth.password` | `admin`, generated | The login, kept on upgrade with the generated session key (and TOTP key) |
| `auth.existingSecret` | `""` | A Secret with keys `password`, `secret-key` (and `totp-key`) instead |
| `settings` | `{}` | More `FLATNOTES_*` settings |
| `persistence.size` | `5Gi` | The notes and the search index (`/data`) |
| `ingress.*` | off | flatnotes has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/flatnotes \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

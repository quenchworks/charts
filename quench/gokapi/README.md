# Quenchworks Gokapi

Hardened [Gokapi](https://github.com/Forceu/Gokapi), lightweight self-hosted file sharing: upload a
file, share a link that expires after a time or a number of downloads, with optional end-to-end
encryption and S3 storage. The image is one static Go binary built from source with upstream's
generated web assets; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by
digest.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/gokapi --set publicUrl=https://files.example.com
kubectl get secret files-gokapi -o jsonpath='{.data.password}' | base64 -d
```

Gokapi has no unattended setup: its first start serves a web wizard, without a login, until it is
submitted. A setup Job submits it right after the install (SQLite on the data volume,
username/password login for `admin.username`, local storage, no end-to-end encryption), and is a
no-op on later upgrades. Keep the Service private until that Job has completed. To pick other
options (OAuth, S3, encryption), set `admin.create: false` and finish the wizard at `/setup`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `publicUrl` | `http://localhost:53842` | The address download links are built from |
| `admin.create`, `admin.username` | `true`, `admin` | The setup Job and the admin it configures |
| `settings` | `{}` | More `GOKAPI_*` env (`GOKAPI_MAX_FILESIZE`, `GOKAPI_TRUSTED_PROXIES`) |
| `persistence.size` | `10Gi` | Data volume: database, uploads and `config.json` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gokapi \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

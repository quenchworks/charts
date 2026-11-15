# Quenchworks SFTPGo

Hardened [SFTPGo](https://github.com/drakkan/sftpgo), a file transfer server for SFTP, FTP/S,
HTTP/S and WebDAV with a web admin, a web client for users and a REST API. Users can keep files on
the volume or in S3, GCS or Azure storage. The image is a static Go binary built from source (the
community edition); it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/sftpgo --set persistence.size=50Gi
kubectl get secret files-sftpgo -o jsonpath='{.data.admin-password}' | base64 -d
```

Sign in at `/web/admin` as `admin.username`, create users, and they sign in at `/web/client` or
over SFTP on port 2022. The admin password is generated once and kept across upgrades.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The first admin, created on the first start |
| `admin.existingSecret` | `""` | A Secret whose key `admin-password` holds the admin password |
| `service.port`, `service.sftpPort` | `8080`, `2022` | Web UI and API, and SFTP |
| `persistence.size` | `10Gi` | The volume: database, host keys, users' files and backups |
| `tls.enabled` | `false` | HTTPS for the web UI and API on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `settings` | `{}` | More `SFTPGO_*` environment variables |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/sftpgo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks dufs

Hardened [dufs](https://github.com/sigoden/dufs), a small file server with a web UI for browsing,
uploading, searching and downloading folders as zip, plus WebDAV and resumable uploads. The image
is one Rust binary built from source; it runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/dufs --set persistence.size=50Gi
kubectl get secret files-dufs -o jsonpath='{.data.password}' | base64 -d
```

The chart creates one read-write account (`auth.username`) with a generated password that is kept
across upgrades. Anonymous requests are refused. WebDAV clients use the same URL and account.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled`, `auth.username` | `true`, `admin` | The account (`DUFS_AUTH`, read-write on `/`) |
| `auth.existingSecret` | `""` | A Secret whose key `auth` holds your own `DUFS_AUTH` rules |
| `allow.upload`, `allow.delete`, `allow.search`, `allow.archive` | `true` | What signed-in users may do (`DUFS_ALLOW_*`) |
| `persistence.size` | `10Gi` | The volume dufs serves (`/data`) |
| `tls.enabled` | `false` | dufs serves HTTPS on port 5000 (existing Secret, cert-manager or a Helm-made CA) |
| `settings` | `{}` | More `DUFS_*` environment variables |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dufs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

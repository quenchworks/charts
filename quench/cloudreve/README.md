# Quenchworks Cloudreve

Hardened [Cloudreve](https://github.com/cloudreve/cloudreve), self-hosted file management and sharing:
a web UI for uploads, folders, previews and share links, storage policies for the local volume or
object storage, and WebDAV. The image is built from source with its React frontend embedded; it runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install drive oci://ghcr.io/quenchworks/charts/cloudreve --set admin.email=you@example.com
kubectl get secret drive-cloudreve -o jsonpath='{.data.admin-password}' | base64 -d
```

Cloudreve makes the first account that registers the administrator. So the chart does not leave that to
chance: a post-install Job registers `admin.email` with a generated password, then turns open
registration off. Set `registration.enabled=true` to let others sign up; the Job re-applies the setting
on every upgrade.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.email` | `admin@example.com` | The administrator, created by the bootstrap Job |
| `admin.existingSecret` | `""` | A Secret with `admin-password` instead of a generated one |
| `registration.enabled` | `false` | Open self-registration for other users |
| `persistence.size` | `10Gi` | conf.ini, the SQLite database and files on the local storage policy |
| `settings` | `{}` | Extra environment variables, e.g. `CR_SETTING_DEFAULT_<name>` defaults |

The image is the core server. Upstream's optional thumbnail and offline-download helpers (ffmpeg,
libvips, LibreOffice, aria2) are not in it; Cloudreve's built-in thumbnails work without them.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cloudreve \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

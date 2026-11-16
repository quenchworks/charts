# Quenchworks PsiTransfer

Hardened [PsiTransfer](https://github.com/psi-4ward/psitransfer): simple self-hosted file sharing with resumable
uploads, expiring links, password-protected buckets and an admin page, no database. The image builds the client and
the Node server from source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install share oci://ghcr.io/quenchworks/charts/psitransfer --set tls.enabled=true
kubectl get secret share-psitransfer -o jsonpath='{.data.upload-password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.uploadPassword` | `true` | Require the upload password to upload |
| `auth.adminPassword`, `auth.uploadPasswordValue` | generated | The admin page and upload passwords, kept on upgrade |
| `auth.existingSecret` | `""` | A Secret with keys `admin-password` and `upload-password` instead |
| `settings` | `{}` | More `PSITRANSFER_*` settings (retention, size limits, bucket passwords) |
| `persistence.size` | `20Gi` | Uploaded files (`/data`) |
| `tls.enabled` | `false` | PsiTransfer's own HTTPS listener (existingSecret, cert-manager or a Helm-generated CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/psitransfer \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks Kopia

Hardened [Kopia](https://github.com/kopia/kopia): fast, encrypted, deduplicated backups. This chart
runs Kopia's repository server with its web UI on a filesystem repository on a volume, so you can
browse snapshots and restore from the UI, and so Kopia clients can back up to it. The image is one
static Go binary built from source; it runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest.

## Install

```bash
helm install backup oci://ghcr.io/quenchworks/charts/kopia --set persistence.size=200Gi
kubectl get secret backup-kopia -o jsonpath='{.data.ui-password}' | base64 -d
kubectl get secret backup-kopia -o jsonpath='{.data.repository-password}' | base64 -d
```

An init container connects to the repository on the volume, or creates it on the first start.
The repository password encrypts every backup and cannot be recovered: copy it somewhere safe.
The Secret has `helm.sh/resource-policy: keep`, so `helm uninstall` leaves it in place.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `repository.password` | generated | Encrypts the repository (`KOPIA_PASSWORD`) |
| `ui.username`, `ui.password` | `admin`, generated | Web UI and API login (basic auth) |
| `existingSecret` | `""` | A Secret with `repository-password` and `ui-password` |
| `tls.enabled` | `false` | Kopia serves HTTPS on 51515 (existing Secret, cert-manager or a Helm-made CA); off runs `--insecure` plain HTTP |
| `persistence.size` | `20Gi` | The repository volume |
| `settings` | `{}` | More `KOPIA_*` environment variables |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kopia \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

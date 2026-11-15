# Quenchworks Restic REST Server

Hardened [Restic REST Server](https://github.com/restic/rest-server), an HTTP backup target for
[restic](https://restic.net): htpasswd accounts, append-only mode for backups a compromised client
cannot delete, private repositories per user, and native TLS. The image is built from source (pure Go);
it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest. A matching restic
client image is `ghcr.io/quenchworks/images/restic`.

## Install

```bash
helm install backup oci://ghcr.io/quenchworks/charts/rest-server --set persistence.size=200Gi --set tls.enabled=true
kubectl get secret backup-rest-server -o jsonpath='{.data.password}' | base64 -d
export RESTIC_REPOSITORY=rest:https://restic:<password>@backup-rest-server:8000/backups
restic init && restic backup /path
```

With the Helm-made CA, pass it to restic with `--cacert` (the CA is `ca.crt` in the `<release>-rest-server-tls` Secret).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.username` | `restic` | The account (password generated into the Secret, bcrypt line in `htpasswd`) |
| `auth.existingSecret` | `""` | A Secret whose key `htpasswd` holds your own bcrypt lines (one per user) |
| `appendOnly` | `false` | Clients can add snapshots but never delete data (prune from a trusted host) |
| `privateRepos` | `false` | Each user reaches only `/<username>/...` repositories |
| `maxRepoSize` | `0` | Repository size limit in bytes (0 = none) |
| `metrics.enabled` | `false` | Prometheus metrics on `/metrics` |
| `persistence.size` | `50Gi` | The repositories (`/data`) |
| `tls.enabled` | `false` | HTTPS on port 8000 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rest-server \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

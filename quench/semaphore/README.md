# Quenchworks Semaphore UI

Hardened [Semaphore UI](https://github.com/semaphoreui/semaphore), a web UI and API for running
Ansible playbooks, Terraform/OpenTofu and shell tasks with projects, inventories, key stores, schedules
and run history. The image is the community build from source with its Vue UI embedded, plus Ansible
from the QuenchWorks ansible package, git and an SSH client. It runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install ops oci://ghcr.io/quenchworks/charts/semaphore
kubectl get secret ops-semaphore -o jsonpath='{.data.admin-password}' | base64 -d
```

An init container creates the admin on the first start. The Secret also holds the session cookie keys
and the key that encrypts stored credentials; it has `helm.sh/resource-policy: keep`, because stored
keys cannot be read without it.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.name`, `admin.email` | `admin`, `Admin`, `admin@example.com` | The first admin |
| `admin.existingSecret` | `""` | A Secret with `admin-password`, `cookie-hash`, `cookie-encryption`, `access-key-encryption` |
| `persistence.size` | `5Gi` | The SQLite database volume |
| `tls.enabled` | `false` | Semaphore serves HTTPS on 3000 (existing Secret, cert-manager or a Helm-made CA) |
| `settings` | `{}` | More `SEMAPHORE_*` environment variables |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/semaphore \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

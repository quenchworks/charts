# Quenchworks Trilium Notes

Hardened [Trilium Notes](https://github.com/TriliumNext/Trilium) (TriliumNext): hierarchical note-taking with rich
text, code notes, scripting, an HTTP API (ETAPI) and sync for the desktop app. The image builds the server and its
web client from source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build, cosign-signed
and pinned by digest.

Upstream asks the first visitor to create the document and set the password. This chart's post-install Job does
both (an empty document, no demo notes), with the password from a generated Secret.

## Install

```bash
helm install notes oci://ghcr.io/quenchworks/charts/trilium \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=notes.example.com' \
  --set 'ingress.tls[0].hosts[0]=notes.example.com' --set 'ingress.tls[0].secretName=notes-tls' \
  --set settings.TRILIUM_NETWORK_TRUSTEDREVERSEPROXY=true
kubectl get secret notes-trilium -o jsonpath='{.data.password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.password` | generated | The login password, set by the Job on a new document |
| `auth.existingSecret` | `""` | A Secret with key `password` instead |
| `settings` | `{}` | More `TRILIUM_*` settings (trusted reverse proxy, backend scripting) |
| `persistence.size` | `5Gi` | `/var/lib/trilium`: the document, backups, logs and `config.ini` |
| `ingress.*` | off | Trilium has no TLS listener: terminate TLS at the Ingress |

Changing the password in the app later: set `auth.password` (or the Secret) to the new one, or the Job's check fails
on the next upgrade.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/trilium \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks SilverBullet

Hardened [SilverBullet](https://github.com/silverbulletmd/silverbullet): Markdown note-taking and a personal knowledge
platform with Lua scripting, live queries, templates and an offline-capable web app. The image builds the client
bundle and the Rust server from source (cargo auditable); it runs as uid 1001 on a read-only root filesystem with
shell commands off, and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install notes oci://ghcr.io/quenchworks/charts/silverbullet \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=notes.example.com' \
  --set 'ingress.tls[0].hosts[0]=notes.example.com' --set 'ingress.tls[0].secretName=notes-tls'
kubectl get secret notes-silverbullet -o jsonpath='{.data.password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled`, `auth.username` | `true`, `admin` | The login (`SB_USER`) |
| `auth.password`, `auth.apiToken` | generated | Login password and API bearer token (`SB_AUTH_TOKEN`), kept on upgrade |
| `auth.existingSecret` | `""` | A Secret with keys `password` and `api-token` instead |
| `settings` | `{}` | More `SB_*` settings (URL prefix, ignored paths, revisions, OIDC) |
| `persistence.size` | `5Gi` | The space: your Markdown files (`/data`) |
| `ingress.*` | off | SilverBullet has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/silverbullet \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

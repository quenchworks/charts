# Quenchworks donetick

Hardened [donetick](https://github.com/donetick/donetick): a chore and task manager for households and teams with
recurring schedules, assignees, points, labels and notifications, on SQLite or PostgreSQL. The image builds the Go
backend and the React frontend from source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install chores oci://ghcr.io/quenchworks/charts/donetick --set publicUrl=https://chores.example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=chores.example.com' \
  --set 'ingress.tls[0].hosts[0]=chores.example.com' --set 'ingress.tls[0].secretName=chores-tls'
# sign up in the web UI, then close signups:
helm upgrade chores oci://ghcr.io/quenchworks/charts/donetick --reuse-values --set signups=false
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `jwt.secret`, `jwt.existingSecret` | generated | JWT signing secret (32+ characters), kept on upgrade |
| `signups` | `true` | Allow new accounts; set `false` once everyone has joined |
| `publicUrl` | `""` | Public URL of the instance |
| `settings` | `{}` | More `DT_<SECTION>_<KEY>` settings (PostgreSQL, email, OAuth2, Telegram) |
| `persistence.size` | `1Gi` | SQLite and the generated config (`/var/lib/donetick`) |
| `ingress.*` | off | donetick has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/donetick \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

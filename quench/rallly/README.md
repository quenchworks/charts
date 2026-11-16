# Quenchworks Rallly

Hardened [Rallly](https://github.com/lukevella/rallly): meeting scheduling polls, a self-hosted Doodle alternative.
People sign in with a code sent by email; poll participants vote without an account. The image builds the Next.js
app from source with an exact Prisma CLI for migrations; it runs as uid 1001 on a read-only root filesystem and is
CVE-gated at build, cosign-signed and pinned by digest.

The chart runs on the bundled QuenchWorks PostgreSQL, generates `SECRET_PASSWORD`, and runs the migrations at start.

## Install

```bash
helm install polls oci://ghcr.io/quenchworks/charts/rallly \
  --set baseUrl=https://polls.example.com --set supportEmail=help@example.com \
  --set smtp.host=smtp.example.com --set smtp.user=rallly --set smtp.password='...' \
  --set allowedEmails='*@example.com' \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=polls.example.com' \
  --set 'ingress.tls[0].hosts[0]=polls.example.com' --set 'ingress.tls[0].secretName=polls-tls'
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `baseUrl` | required | The public URL (`NEXT_PUBLIC_BASE_URL`); sign-in checks the request origin against it |
| `supportEmail` | required | Help address shown to users |
| `smtp.*` | unset | SMTP for sign-in codes and notifications; without it nobody can sign in |
| `allowedEmails` | `""` | Who may register, e.g. `*@example.com`; empty allows anyone |
| `secret.existingSecret` | `""` | A Secret with `secret-password` (32+ characters) instead of the generated one |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.existingSecret` with a `DATABASE_URL` |
| `settings` | `{}` | More Rallly environment variables (OIDC, moderation, log level) |
| `ingress.*` | off | Rallly has no TLS listener: terminate TLS at the Ingress |

Open core: without a Rallly license key a space has one seat. Paid features stay off.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rallly \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

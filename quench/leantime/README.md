# Quenchworks Leantime

Hardened [Leantime](https://github.com/Leantime/leantime): project management for non-project-managers, with tasks,
kanban boards, timesheets, goals and ideas. The image builds Leantime from source (composer with the fixed Laravel,
Symfony, phpseclib, lightsaml and jmespath releases, the front end compiled at build time) on Wolfi PHP 8.5 with
php-fpm and nginx; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build, cosign-signed and
pinned by digest. One finding without a usable fix (php-jwt's HMAC key length, unreachable: Leantime's SSO providers
verify RSA tokens) is documented in a VEX statement.

The chart runs on the bundled QuenchWorks PostgreSQL, keeps uploads, caches and sessions on a PersistentVolumeClaim,
and generates the session secret and the first admin's password once. On every start the image runs
`bin/leantime db:migrate`: the first install loads the schema and creates the admin, later starts apply the updates.

## Install

```bash
helm install pm oci://ghcr.io/quenchworks/charts/leantime \
  --set appUrl=https://pm.example.com \
  --set admin.email=you@example.com
```

Then read the admin password from the chart Secret (see the install notes) and sign in.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `appUrl` | `""` | Public URL, required |
| `admin.email` | `""` | First admin, required |
| `admin.password` | `""` | Generated when empty |
| `persistence.size` | `5Gi` | Uploads, caches, sessions (`/var/lib/leantime`) |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` (`connection: pgsql` or `mysql`) |
| `secret.existingSecret` | `""` | Secret with keys `session-password` and `admin-password` |
| `settings` | `{}` | More `LEAN_*` settings (site name, timezone, mail) |
| `ingress.*` | off | No TLS listener: terminate TLS here and set `appUrl` to the https URL |

Leantime runs one replica (uploads on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/leantime \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

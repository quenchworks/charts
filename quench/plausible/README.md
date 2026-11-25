# Quenchworks Plausible

Hardened [Plausible Analytics](https://github.com/plausible/analytics) Community Edition: simple, privacy-friendly
web analytics without cookies. The image is a mix release built from source with `MIX_ENV=ce`, with the
proprietary `extra/` directory removed before the build (the build fails if any of its modules reach the release).
It runs as uid 1001 on a read-only rootfs and is CVE-gated at build, cosign-signed and pinned by digest.

The chart runs Plausible on the bundled QuenchWorks PostgreSQL (accounts, sites) and ClickHouse (events). Two
init containers create the databases and run the migrations before every start.

## Install

```bash
helm install analytics oci://ghcr.io/quenchworks/charts/plausible \
  --set domain=plausible.example.com \
  --set ingress.enabled=true --set ingress.className=nginx \
  --set 'ingress.tls[0].hosts[0]=plausible.example.com' --set 'ingress.tls[0].secretName=plausible-tls'
```

Open `https://plausible.example.com`, register the first account, add a site and put its snippet on your pages.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | required | The public host (BASE_URL) |
| `publicScheme` | `https` | `http` only for testing |
| `disableRegistration` | `""` | `false`, `invite_only` or `true`; empty keeps upstream's default |
| `env` | `{}` | More Plausible settings (mailer, SMTP, Google integration) |
| `secret.existingSecret` | `""` | Your own `secret-key-base` (64+ characters) |
| `postgresql.enabled` / `clickhouse.enabled` | `true` | The bundled stores; `false` reads `externalDatabase.existingSecret` |
| `externalDatabase.existingSecret` | `""` | Keys `database-url` and `clickhouse-database-url` |
| `ingress.enabled` | `false` | One Ingress for `domain` |
| `networkPolicy.enabled` | `true` | Ingress allowed on 8000 only |

Keep `secret-key-base`: sessions and the two-factor (TOTP) vault key derive from it. The chart generates it once
and keeps it on upgrade.

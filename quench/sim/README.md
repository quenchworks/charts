# Quenchworks Sim

Hardened [Sim](https://github.com/simstudioai/sim): a visual builder for AI agent workflows, and a maintained
replacement for Flowise (archived upstream on 2026-08-13). The images build the Next.js app, the realtime server and
the migrations from source on Wolfi and run them on Bun; they run as uid 1001 on a read-only root filesystem and are
CVE-gated at build, cosign-signed and pinned by digest. They keep upstream's better-auth 1.6.27 (the fixed 1.7 line
breaks the build); its advisories need plugins and settings Sim does not use, and the image's
[VEX](https://quench-works.com/vex/sim/2026-11-18) records the evidence for each.

The chart runs:

- the app, with the database migrations as its init container (`sim-migrations` of the same release);
- the realtime server (`sim-realtime`, socket.io on 3002) for the collaborative editor;
- one CronJob per schedule for scheduled workflows, webhook polling and cleanups, calling the app with `CRON_SECRET`;
- the bundled QuenchWorks PostgreSQL, which ships pgvector.

It generates `BETTER_AUTH_SECRET`, `ENCRYPTION_KEY`, `INTERNAL_API_SECRET` and `CRON_SECRET` once and keeps them on
upgrade. `ENCRYPTION_KEY` encrypts stored credentials: back up the Secret `<release>-sim`.

## Install

```bash
helm install sim oci://ghcr.io/quenchworks/charts/sim \
  --set baseUrl=https://sim.example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=sim.example.com' \
  --set 'ingress.tls[0].hosts[0]=sim.example.com' --set 'ingress.tls[0].secretName=sim-tls'
```

The first visitor signs up at `/signup`. Model providers are keys you add in the workspace, or environment variables
through `settings` and `extraEnvVarsSecret` (for example `OPENAI_API_KEY`, or `OLLAMA_URL` for a local Ollama).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `baseUrl` | required | The public URL (`NEXT_PUBLIC_APP_URL`, `BETTER_AUTH_URL`); sign-in checks the request origin against it |
| `socketUrl` | `""` | Where browsers reach the realtime server; empty means the page origin under `/socket.io` (the Ingress routes it) |
| `secret.existingSecret` | `""` | A Secret with `better-auth-secret`, `encryption-key`, `internal-api-secret`, `cron-secret` instead |
| `realtime.enabled` | `true` | The realtime server; set `REDIS_URL` in `settings` before raising `realtime.replicaCount` |
| `cronjobs.enabled` | `true` | Scheduled work; `cronjobs.jobs` maps a name to a `schedule` and the `paths` it calls |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.existingSecret` with a `DATABASE_URL` to a server with pgvector |
| `settings` | `{}` | More Sim environment variables on the app and realtime pods |
| `ingress.*` | off | Sim has no TLS listener: terminate TLS at the Ingress, which routes `/socket.io` to realtime |

With your own PostgreSQL, the migrations run `CREATE EXTENSION vector`, which needs a role allowed to create it.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/sim \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

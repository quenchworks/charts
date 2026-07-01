# Authentik (QuenchWorks)

Hardened [Authentik](https://github.com/goauthentik/authentik) identity provider
(OIDC / SAML / LDAP / SCIM) on a 0-CVE, nonroot (uid 1001), multi-arch, cosign-signed
image with an SBOM and SLSA provenance. Clean-room chart authored from Authentik's own
upstream documentation.

- **Image:** `ghcr.io/quenchworks/images/authentik`, pinned by digest.
- **App version:** `2026.5.3` (also built: `2026.2.4`, `2025.12.6`).
- **License:** MIT (upstream Authentik).

## Architecture: two workloads, one image

Authentik runs as **two Deployments from the same image**, both sharing the same
config (secret key + PostgreSQL + Redis):

| Workload  | Entrypoint  | Ports              | Purpose                                                        |
| --------- | ----------- | ------------------ | -------------------------------------------------------------- |
| `server`  | `ak server` | 9000 (HTTP), 9443 (HTTPS) | Web UI, API, outpost endpoint.                          |
| `worker`  | `ak worker` | none               | Background tasks: **DB migrations on boot**, blueprints, outpost management, e-mail, scheduled/async tasks. |

The `Service` selects the **server** only (the worker has no listener). On a fresh
install the worker migrates the schema first; the server then passes
`/-/health/ready/`.

Health endpoints on the server (port 9000):

- liveness: `/-/health/live/`
- readiness: `/-/health/ready/` (200 once DB is migrated/reachable and Redis is up)

The worker uses the bundled `ak healthcheck` command as its liveness/readiness exec
probe.

## Hard dependencies: PostgreSQL and Redis

Authentik **cannot boot without both** a PostgreSQL and a Redis. This chart makes each
choosable as **bundled** (a QuenchWorks subchart) or **external** (your own), mirroring
the `quench/authelia` layout. Exactly one mode per backend must resolve, or rendering
fails with a clear message — there is no standalone fallback.

### Database

| Mode | How | Notes |
| ---- | --- | ----- |
| **Bundled** (default) | `postgresql.enabled=true` | Pulls the QuenchWorks `postgresql` subchart; connects to `<release>-postgresql:5432`. Password read from the subchart's own Secret. `postgresql.auth.username` and `.database` **must differ** (the bundled image only creates the app DB when it differs from both `postgres` and the superuser name). |
| **External** | `postgresql.enabled=false` + `externalDatabase.host=…` | Point at any reachable PostgreSQL. Password inline (`externalDatabase.password`) or via `externalDatabase.existingSecret` (+`existingSecretPasswordKey`). |

### Redis

| Mode | How | Notes |
| ---- | --- | ----- |
| **Bundled valkey** (default, recommended) | `valkey.enabled=true` | 0-CVE, BSD-licensed, Redis-wire-compatible; connects to `<release>-valkey:6379`. Password read from valkey's own Secret. |
| **Bundled redis** (AGPL alternative) | `redis.enabled=true` | Connects to `<release>-redis:6379`. Enable **at most one** of valkey/redis; valkey wins if both are set. |
| **External** | both bundled off + `externalRedis.host=…` | Point at any reachable Redis/Valkey. Password inline or via `externalRedis.existingSecret`. |

Mix-and-match is allowed (e.g. bundled PG + external Redis).

## AUTHENTIK_SECRET_KEY

Authentik requires a **≥ 50-char secret key** (`AUTHENTIK_SECRET_KEY`) to sign
cookies/tokens. It is delivered from a Secret key `authentik-secret-key`:

- Leave `secrets.secretKey` empty → the chart **generates a 50-char value once** and
  preserves it across upgrades (via a lookup of the existing Secret).
- Set `secrets.secretKey` → uses that value.
- Set `secrets.existingSecret` (+ `existingSecretKey`, default `authentik-secret-key`)
  → the chart reads the key from your own Secret and generates nothing.

Backend passwords are never duplicated in plaintext: bundled backends read the
subchart's own Secret, external-with-`existingSecret` reads that Secret, and only
external-inline passwords are stored in the chart-managed Secret.

## Quick start (bundled backends)

```bash
helm install authentik oci://ghcr.io/quenchworks/charts/authentik
kubectl port-forward svc/authentik 9000:80
# complete initial setup:
open http://127.0.0.1:9000/if/flow/initial-setup/
```

## External backends example

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.internal
  port: 5432
  database: authentik
  username: authentik
  existingSecret: authentik-db
  existingSecretPasswordKey: password

valkey:
  enabled: false
redis:
  enabled: false
externalRedis:
  host: redis.example.internal
  port: 6379
  existingSecret: authentik-redis
  existingSecretPasswordKey: redis-password

secrets:
  existingSecret: authentik-secretkey   # key: authentik-secret-key
```

## Key values

| Key | Default | Description |
| --- | ------- | ----------- |
| `image.digest` | pinned by CI | Image digest (never a tag). |
| `server.replicaCount` / `worker.replicaCount` | `1` / `1` | Per-workload replicas. |
| `postgresql.enabled` | `true` | Bundle the QuenchWorks PostgreSQL subchart. |
| `valkey.enabled` | `true` | Bundle the recommended valkey session/cache store. |
| `redis.enabled` | `false` | Bundle redis (AGPL) instead of valkey. |
| `media.persistence.enabled` | `true` | PVC mounted at `/media` (uploaded assets), shared by both workloads. Use RWX for multi-node/multi-replica. |
| `secrets.secretKey` | `""` (generated) | AUTHENTIK_SECRET_KEY. |
| `config.errorReporting` | `false` | Sentry error reporting (off = no phone-home). |
| `networkPolicy.enabled` | `true` | Restrict ingress to the server workload. |

## Notes

- Runs nonroot uid 1001 with a read-only root filesystem; writable `/tmp` (emptyDir)
  and `/media` (PVC or emptyDir).
- The `/media` PVC is `ReadWriteOnce` by default. For more than one node or replica,
  set `media.persistence.accessModes: ["ReadWriteMany"]` (with an RWX storage class) or
  configure an external object store via `config.extra`.

Verify the image:

```bash
cosign verify ghcr.io/quenchworks/images/authentik \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

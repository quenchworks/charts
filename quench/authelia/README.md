# Quenchworks Authelia

Hardened [Authelia](https://github.com/authelia/authelia) — an open-source
authentication and authorization server providing SSO, 2FA, and forward-auth —
on a minimal, nonroot, 0-CVE image, built from source and pinned by digest.

## Install

```sh
helm install auth oci://ghcr.io/quenchworks/charts/authelia
```

It runs nonroot (uid 1001) and serves the portal and the `/api/health` endpoint
on container port 9091; the Service exposes it on the same port. Check health
over a port-forward:

```sh
kubectl port-forward svc/auth-authelia 9091:9091
curl http://127.0.0.1:9091/api/health
```

## How it boots with no external dependencies

The default install is fully standalone:

- **Storage**: SQLite at `/data/db.sqlite3` on a ReadWriteOnce PVC.
- **Auth backend**: the file backend; a default user `authelia` is seeded into
  `/config/users.yml` (rendered from the `auth.file` values into the config
  ConfigMap, mounted read-only).
- **Notifier**: filesystem (`/data/notification.txt`) — no SMTP required.

Because storage and session state are local, the default runs a single replica
with a `Recreate` update strategy.

## The three mandatory secrets

Authelia refuses to boot unless `identity_validation.reset_password.jwt_secret`,
`session.secret`, and `storage.encryption_key` are each set and at least 20
characters. The chart never places these in the ConfigMap. It renders them into a
Secret and injects them via the `*_FILE` env vars
(`AUTHELIA_*_FILE`) pointing at files mounted under `/secrets`. Leave the
`secrets.*` values empty to have the chart generate 32-char values once and
preserve them across upgrades, or set `secrets.existingSecret` to manage your own
(keys: `jwt-secret`, `session-secret`, `storage-encryption-key`).

## Configuration

The full Authelia config lives under the `configuration` value and is rendered
verbatim into a ConfigMap mounted read-only at `/config/configuration.yml`
(passed via `--config`). The shipped default is bootable but **not** production-
ready: change `configuration.session.cookies[].domain` / `authelia_url` to your
real domain, replace the default user/password, tighten `access_control`, and
switch the notifier to SMTP.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/authelia` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | single replica (local storage + session) |
| `secrets.existingSecret` | `""` | manage the 3 secrets yourself |
| `auth.file.enabled` | `true` | file auth backend with a seeded user |
| `auth.file.passwordHash` | argon2id of `authelia` | CHANGE THIS |
| `configuration` | bootable default | rendered to `/config/configuration.yml` |
| `persistence.enabled` | `true` | PVC at `/data` (SQLite + notifier) |
| `persistence.size` | `1Gi` | |
| `service.type` | `ClusterIP` | |
| `service.port` | `9091` | HTTP portal + `/api/health` |

## Optional backends — PostgreSQL storage and a Redis session store

The default install is fully standalone (SQLite + in-memory session, **no extra
services**). For production scale-out you can independently turn on two optional
backends; they are unrelated, so any combination is valid (e.g. bundled PostgreSQL
with an external Redis). HA (`replicaCount > 1`) requires **both** a shared SQL
store and a shared session store.

When a backend is enabled the chart edits the rendered Authelia config for you —
adding `storage.postgres` (and dropping the SQLite `storage.local`) and/or
`session.redis` — and injects each password as a file via a `*_FILE` env var.
You never put backend passwords in the ConfigMap.

### Storage (SQL)

Resolution order: **bundled PostgreSQL → external PostgreSQL → SQLite (default)**.

```sh
# bundled: installs the QuenchWorks postgresql subchart as a dependency
helm install auth oci://ghcr.io/quenchworks/charts/authelia \
  --set postgresql.enabled=true --set postgresql.auth.password=<pw>

# external: point at your own PostgreSQL
helm install auth oci://ghcr.io/quenchworks/charts/authelia \
  --set externalDatabase.host=db.example --set externalDatabase.password=<pw>

# default: neither set → SQLite, nothing extra installed
```

### Session

Resolution order: **bundled Valkey → bundled Redis → external → in-memory (default)**.
Valkey is the recommended 0-CVE, BSD-licensed, Redis-wire-compatible store; Redis is
the AGPL alternative. Enable **at most one** of `valkey.enabled` / `redis.enabled`
(if both are set, Valkey wins).

```sh
# bundled valkey (recommended)
helm install auth oci://ghcr.io/quenchworks/charts/authelia \
  --set valkey.enabled=true

# bundled redis (AGPL alternative)
helm install auth oci://ghcr.io/quenchworks/charts/authelia \
  --set redis.enabled=true

# external Redis/Valkey
helm install auth oci://ghcr.io/quenchworks/charts/authelia \
  --set externalRedis.host=cache.example --set externalRedis.password=<pw>

# default: none set → in-memory sessions
```

For bundled stores Authelia reads the subchart's own Secret directly, so leaving
the password empty (subchart-generated) is safe. Connections target the rendered
subchart Services: `<release>-postgresql:5432`, `<release>-valkey:6379`, or
`<release>-redis:6379`.

### Backend values

| Value | Default | Notes |
|-------|---------|-------|
| `postgresql.enabled` | `false` | install the bundled PostgreSQL subchart |
| `postgresql.auth.username` | `authelia` | bundled DB user (≠ database) |
| `postgresql.auth.password` | `""` | bundled DB password (generated if empty) |
| `postgresql.auth.database` | `authelia` | bundled database name |
| `externalDatabase.host` | `""` | external PostgreSQL host (enables external mode) |
| `externalDatabase.port` | `5432` | |
| `externalDatabase.database` | `authelia` | |
| `externalDatabase.username` | `authelia` | |
| `externalDatabase.password` | `""` | inline password (ignored if `existingSecret` set) |
| `externalDatabase.existingSecret` | `""` | Secret holding the DB password |
| `externalDatabase.existingSecretPasswordKey` | `password` | key within that Secret |
| `valkey.enabled` | `false` | bundled Valkey session store (recommended) |
| `valkey.auth.password` | `""` | generated by the subchart if empty |
| `redis.enabled` | `false` | bundled Redis session store (AGPL alternative) |
| `redis.auth.password` | `""` | generated by the subchart if empty |
| `externalRedis.host` | `""` | external Redis/Valkey host (enables external mode) |
| `externalRedis.port` | `6379` | |
| `externalRedis.password` | `""` | inline password (ignored if `existingSecret` set) |
| `externalRedis.existingSecret` | `""` | Secret holding the Redis password |
| `externalRedis.existingSecretPasswordKey` | `redis-password` | key within that Secret |

## Image verification

```sh
cosign verify ghcr.io/quenchworks/images/authelia \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

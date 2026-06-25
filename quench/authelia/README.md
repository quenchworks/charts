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

## Scaling out (PostgreSQL + Redis)

For HA, move storage to PostgreSQL and the session store to Redis by editing the
`configuration.storage` and `configuration.session` blocks (commented examples in
`values.yaml`) to point at externally-managed instances, then raise
`replicaCount`. These backends are intentionally not bundled subcharts.

## Image verification

```sh
cosign verify ghcr.io/quenchworks/images/authelia \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

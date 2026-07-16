# Quenchworks PgBouncer

Hardened [PgBouncer](https://www.pgbouncer.org/) — a lightweight connection pooler for
PostgreSQL — on a minimal, nonroot, 0-CVE image pinned by digest. PgBouncer sits between
your applications and PostgreSQL, multiplexing many short-lived client connections onto a
small pool of long-lived server connections. The pooler listens on port `6432`.

Built from the official PgBouncer source on Wolfi (OpenSSL + c-ares, no PAM/systemd). The
runtime runs as uid 1001 on a read-only root filesystem; its unix socket + pidfile live in
an emptyDir at `/var/run/pgbouncer`, logs go to stderr.

This chart bundles the Quenchworks PostgreSQL chart by default (for a self-contained
demo/gate) and is designed to front an **external** PostgreSQL in production.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install pool oci://ghcr.io/quenchworks/charts/pgbouncer
```

## Connect

Point your applications at the pooler instead of PostgreSQL directly:

```
host : pool-pgbouncer
port : 6432
user : appuser
db   : appdb
```

```bash
# bundled PG password
PW=$(kubectl get secret pool-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

# verify pooling end-to-end (psql ships in the Quenchworks postgresql image)
kubectl run pgclient --rm -it --restart=Never \
  --image=ghcr.io/quenchworks/images/postgresql:18.4 -- \
  psql "host=pool-pgbouncer port=6432 user=appuser dbname=appdb password=$PW" -c 'SELECT 1;'
```

### Admin / stats console

Connect to the special `pgbouncer` virtual database as an admin user:

```bash
psql "host=pool-pgbouncer port=6432 user=appuser dbname=pgbouncer password=$PW" -c 'SHOW POOLS;'
# also: SHOW LISTS; SHOW STATS; SHOW CLIENTS; RELOAD;
```

## Backend database

### External (production)

The real use case: pool client connections in front of an existing PostgreSQL. Set
`postgresql.enabled=false` and fill in `externalDatabase`:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.com
  port: 5432
  database: appdb
  user: appuser
  password: ""               # or supply existingSecret (then also set userlist.existingSecret)
  existingSecret: ""
  existingSecretPasswordKey: password
```

### Bundled (demo / CI)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart. PgBouncer and PG
share deterministic credentials under `postgresql.auth`, so the generated `userlist.txt`
and the backend route are derived automatically:

```yaml
postgresql:
  enabled: true
  auth:
    username: appuser        # MUST differ from `database` (image init quirk)
    password: appsecret      # set a real password in production
    database: appdb
```

## Pooling

`pool_mode` controls when a server connection returns to the pool:

| Mode | Behavior | Use when |
|------|----------|----------|
| `transaction` (default) | Returns the server at the end of each transaction. | Best throughput; apps that don't rely on session state. |
| `session` | One server connection per client connection. | Most compatible; needs `SET`, advisory locks, session prepared statements. |
| `statement` | Returns after every statement (autocommit only). | Aggressive pooling for stateless autocommit workloads. |

Total backend connections ≈ `replicaCount × default_pool_size × (databases × users)`.

## Authentication

`pgbouncer.authType` selects how PgBouncer authenticates **clients** connecting to it. The
Quenchworks PostgreSQL uses `scram-sha-256`. The chart writes a `userlist.txt` Secret (the
`auth_file`) with `"user" "password"` entries; with `scram-sha-256` PgBouncer uses the
plaintext password to verify the client over SCRAM **and** to log in to the backend. For
the bundled PG the entry is generated from `postgresql.auth`; for an external DB it is
generated from `externalDatabase.password`. Add extra users via `userlist.extraUsers`, or
supply a fully managed file with `userlist.existingSecret`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pgbouncer \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/pgbouncer --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/pgbouncer` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless pooler; raise to scale (watch total backend connections). |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart (demo/CI). |
| `postgresql.auth.{username,password,database}` | `appuser`/`appsecret`/`appdb` | Deterministic shared creds; user ≠ database. |
| `externalDatabase.*` | `""` | Backend used when `postgresql.enabled=false` (production). |
| `pgbouncer.authType` | `scram-sha-256` | Client auth (`scram-sha-256` / `md5` / `trust`). |
| `pgbouncer.poolMode` | `transaction` | `transaction` / `session` / `statement`. |
| `pgbouncer.maxClientConn` | `1000` | Max client connections to the pooler. |
| `pgbouncer.defaultPoolSize` | `25` | Server connections per (user, db). |
| `pgbouncer.adminUsers` | `appuser` | Users allowed on the `pgbouncer` admin console. |
| `pgbouncer.ignoreStartupParameters` | `extra_float_digits` | Startup params to ignore rather than reject. |
| `pgbouncer.raw` | `""` | Full pgbouncer.ini to bypass templating (advanced). |
| `userlist.existingSecret` | `""` | Provide your own `userlist.txt` Secret. |
| `userlist.extraUsers` | `{}` | Extra `{user: password}` entries appended to the generated list. |
| `service.port` | `6432` | Pooler listener. |
| `networkPolicy.enabled` | `true` | Ingress 6432 (in-namespace), egress to DB + DNS. |
| `networkPolicy.allowExternal` | `false` | Set true to accept connections from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped. The
only writable paths are emptyDir mounts at `/var/run/pgbouncer` (socket + pidfile) and
`/tmp`. The `pgbouncer.ini` ConfigMap and `userlist.txt` Secret are mounted read-only under
`/etc/pgbouncer`. Credentials live in a Kubernetes Secret. A tcpSocket probe on 6432 gates
readiness and liveness.

## Uninstall

```bash
helm uninstall pool
```

The pooler itself is stateless and holds no PVCs. When the bundled PostgreSQL
subchart is enabled, its PVC is retained by Kubernetes on uninstall — delete it
explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=pool
```

## Notes

Depends on the `quench-common` library chart and the Quenchworks `postgresql` chart, both
pulled from `oci://ghcr.io/quenchworks/charts`. The chart supplies the real `pgbouncer.ini`
(the image ships only a minimal sample) at the entrypoint's path `/etc/pgbouncer/pgbouncer.ini`.

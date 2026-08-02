# Apache Airflow (Quenchworks)

Clean-room Helm chart for [Apache Airflow](https://airflow.apache.org/) 3, running on the
hardened, 0-CVE, digest-pinned `ghcr.io/quenchworks/images/airflow` image (nonroot uid
1001, read-only root filesystem, multi-arch, cosign-signed with SBOM + SLSA provenance).

Airflow 3 runs each role as a **separate workload from the same image**; the chart passes
the per-component subcommand:

| Workload        | Command                 | Notes                                             |
| --------------- | ----------------------- | ------------------------------------------------- |
| `api-server`    | `airflow api-server`    | UI + REST API + Task Execution API on port 8080   |
| `scheduler`     | `airflow scheduler`     | schedules DAG runs (and runs tasks in LocalExecutor) |
| `dag-processor` | `airflow dag-processor` | standalone DAG file parser (Airflow 3)            |
| `triggerer`     | `airflow triggerer`     | async loop for deferrable tasks                   |
| `worker`        | `airflow celery worker` | **CeleryExecutor only** — executes tasks          |

## Executor

Set with `executor`:

- **`LocalExecutor`** (default) — the scheduler runs tasks in-process. No broker, no
  worker. The simplest topology: `api-server` + `scheduler` + `dag-processor` +
  `triggerer` + a bundled/external PostgreSQL.
- **`CeleryExecutor`** — adds a `worker` workload and a Redis/valkey broker. Set
  `executor: CeleryExecutor` and enable exactly one broker (`valkey.enabled`,
  `redis.enabled`, or `externalRedis.host`). The chart wires
  `AIRFLOW__CELERY__BROKER_URL` and `AIRFLOW__CELERY__RESULT_BACKEND` automatically.

## Metadata database (required)

Airflow refuses to boot without a PostgreSQL metadata database. Choose one mode:

- **Bundled** (default): `postgresql.enabled=true` deploys the QuenchWorks PostgreSQL
  subchart. `postgresql.auth.username` and `postgresql.auth.database` must differ (the
  bundled image only creates the app database when it differs from both `postgres` and the
  superuser name).
- **External**: `postgresql.enabled=false` + set `externalDatabase.host` (and
  `username`/`database`/`port`). Supply the password inline (`externalDatabase.password`)
  or via `externalDatabase.existingSecret` (+ `existingSecretPasswordKey`). The password
  must be URL-safe — it is embedded in the SQLAlchemy connection string.

The chart assembles `AIRFLOW__DATABASE__SQL_ALCHEMY_CONN` from discrete env vars using
Kubernetes `$(VAR)` interpolation, so the password is sourced from a Secret and never
written into a ConfigMap.

## Broker (CeleryExecutor only)

- **Bundled valkey** (recommended, 0-CVE BSD): `valkey.enabled=true`.
- **Bundled redis** (AGPL alternative): `redis.enabled=true`. Enable at most one of
  valkey/redis; valkey wins if both are set.
- **External**: `externalRedis.host` (+ password inline or via `existingSecret`).

## Database migration + component startup

Airflow needs `airflow db migrate` run once before the components can serve. The chart
runs it as a **normal Job** (`<release>-airflow-db-migrate-<revision>`), not a Helm
pre-install hook — a pre-install hook would execute before the bundled PostgreSQL subchart
exists and could never reach it. The Job retries (`migrateDatabase.backoffLimit`) until
PostgreSQL accepts connections and the migration applies. Every component additionally
blocks in an `airflow db check-migrations` **init container** until the schema is up to
date (`migrateDatabase.waitTimeout` seconds). Under `helm install --wait` this chain
reaches Ready for both bundled and external databases.

## Fernet key + JWT secret

- **Fernet key** (`AIRFLOW__CORE__FERNET_KEY`) encrypts connections/variables at rest.
- **JWT secret** (`AIRFLOW__API_AUTH__JWT_SECRET`) must be identical across every
  component — they authenticate to the api-server's Task Execution API with it.

Leave `secrets.fernetKey` / `secrets.jwtSecret` empty and the chart generates both once
and preserves them across upgrades via a lookup of the existing Secret. The Fernet key is
generated as a valid url-safe base64 key. To manage them yourself, set
`secrets.existingSecret` (keys `fernet-key`, `jwt-secret`, overridable via
`existingSecretFernetKey` / `existingSecretJwtKey`).

## Admin user / auth

Airflow 3 defaults to **SimpleAuthManager** (the image ships no FAB provider, so there is
no `airflow users create` step). Users are **declared** via `auth.users` as
`"username:role"` pairs (default `admin:admin`); each user's password is auto-generated on
api-server boot and written to `$AIRFLOW_HOME/simple_auth_manager_passwords.json.generated`
(and printed in the api-server logs):

```sh
kubectl logs deployment/<release>-airflow-api-server | grep -i password
```

Set `auth.allAdmins=true` to disable login entirely and treat everyone as admin
(development/gate only). To use a different auth manager, set
`AIRFLOW__CORE__AUTH_MANAGER` via `config.extra` and ship the matching provider in a
custom image.

## Quick start

```sh
# LocalExecutor + bundled PostgreSQL (default)
helm install airflow oci://ghcr.io/quenchworks/charts/airflow

# CeleryExecutor + bundled valkey broker
helm install airflow oci://ghcr.io/quenchworks/charts/airflow \
  --set executor=CeleryExecutor --set valkey.enabled=true

# External PostgreSQL
helm install airflow oci://ghcr.io/quenchworks/charts/airflow \
  --set postgresql.enabled=false \
  --set externalDatabase.host=pg.example.com \
  --set externalDatabase.username=airflow \
  --set externalDatabase.database=airflow \
  --set externalDatabase.password=secret
```

Then port-forward and open the UI / hit health:

```sh
kubectl port-forward svc/airflow 8080:8080
curl http://127.0.0.1:8080/api/v2/monitor/health   # HTTP 200 once up
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `executor` | `LocalExecutor` | `LocalExecutor` or `CeleryExecutor` |
| `image.digest` | pinned | image is always resolved by digest, never a tag |
| `apiServer.replicaCount` | `1` | api-server replicas |
| `scheduler.replicaCount` | `1` | scheduler replicas |
| `dagProcessor.replicaCount` | `1` | dag-processor replicas |
| `triggerer.replicaCount` | `1` | triggerer replicas |
| `worker.replicaCount` | `1` | Celery worker replicas (CeleryExecutor only) |
| `migrateDatabase.enabled` | `true` | run the `airflow db migrate` Job |
| `migrateDatabase.backoffLimit` | `12` | migrate Job retries while waiting for PostgreSQL |
| `migrateDatabase.waitTimeout` | `300` | init-container `check-migrations` timeout (s) |
| `secrets.fernetKey` | generated | Fernet key (url-safe base64 of 32 bytes) |
| `secrets.jwtSecret` | generated | shared Task Execution API JWT secret |
| `auth.users` | `admin:admin` | SimpleAuthManager `user:role` pairs |
| `auth.allAdmins` | `false` | disable login, everyone admin (dev only) |
| `postgresql.enabled` | `true` | bundle PostgreSQL vs. use `externalDatabase.*` |
| `valkey.enabled` / `redis.enabled` | `false` | Celery broker (bundled) |
| `service.port` | `8080` | api-server Service port |
| `networkPolicy.enabled` | `true` | restrict ingress to the api-server |
| `podDisruptionBudget.enabled` | `true` | PDB for the api-server |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
## Image provenance

```sh
cosign verify ghcr.io/quenchworks/images/airflow \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/airflow --owner quenchworks`.

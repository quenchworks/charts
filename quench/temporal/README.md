# Quenchworks Temporal

Hardened [Temporal](https://temporal.io/) — a durable workflow execution engine —
on a minimal, nonroot, 0-CVE image pinned by digest. This chart runs the
**single-binary all-in-one** server: one `temporal-server` process hosting all four
roles (frontend + history + matching + worker), backed by **PostgreSQL**.

All durable state lives in Postgres, so the server runs on a read-only root
filesystem. This chart bundles the Quenchworks PostgreSQL chart by default and can
also point at an external database.

Temporal uses **two databases**: the main store and the visibility store. A
schema-setup Job (a Helm pre-install/pre-upgrade hook) creates both and brings their
schema to the latest version with `temporal-sql-tool` before the server boots.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install wf oci://ghcr.io/quenchworks/charts/temporal
```

## Connect

The frontend gRPC port `7233` is the main client/worker endpoint.

```bash
kubectl port-forward svc/wf-temporal 7233:7233
# point your SDK Client at 127.0.0.1:7233, namespace "default"
```

The `temporal` CLI and the Web UI are **separate** components (not in this image).
Register the namespaces your workers use with the standalone CLI:

```bash
temporal operator namespace create --address 127.0.0.1:7233 my-namespace
```

Metrics (Prometheus, tally) are on `:8000/metrics`:

```bash
kubectl port-forward svc/wf-temporal 8000:8000
curl -fsS http://127.0.0.1:8000/metrics
```

## Database

By default the chart bundles PostgreSQL with deterministic credentials shared by
Temporal, the schema-setup Job, and the bundled PG (`postgresql.auth`). Because the
bundled PG only creates its application database when the database name differs from
both `postgres` and the superuser name, the defaults use a **distinct** user/db
(`temporal_user` / `temporal`). The bundled PG seeds the main store; the
schema-setup Job creates the visibility store (`temporal_visibility`).

Use an external database instead:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: postgres.example.com
  port: 5432
  user: temporal_user
  password: "..."        # or existingSecret + existingSecretPasswordKey
databases:
  main: temporal
  visibility: temporal_visibility
```

The external user must be able to create databases and schemas.

## Configuration

The server config is the `temporalConfig` value (a Postgres-backed config rendered
through `tpl`, replacing the upstream sqlite sample). It is mounted at
`/etc/temporal/config/production.yaml`; `dynamicConfig` is mounted alongside. Edit
either and `helm upgrade` — the pod checksum annotation rolls the Deployment.

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Keep at 1 for the all-in-one server. |
| `numHistoryShards` | `512` | Fixed at first schema setup; cannot change later. |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL chart. |
| `postgresql.auth.{username,password,database}` | `temporal_user` / `temporal` / `temporal` | Deterministic shared DB creds. |
| `databases.{main,visibility}` | `temporal` / `temporal_visibility` | Store database names. |
| `externalDatabase.*` | — | Used when `postgresql.enabled=false`. |
| `schemaSetup.enabled` | `true` | Run the schema-setup Job hook. |
| `service.{grpcPort,httpPort,metricsPort}` | `7233` / `7243` / `8000` | Service ports. |
| `networkPolicy.allowExternal` | `false` | Allow frontend ingress from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | PDB (`minAvailable: 1`). |

Standard quench-common knobs (`resources`, `nodeSelector`, `affinity`, `tolerations`,
`podSecurityContext`, `containerSecurityContext`, probe overrides, `extraEnvVars`,
`extraVolumes`/`extraVolumeMounts`, `sidecars`, `initContainers`, …) are also
supported.

## Scaling

This release ships the all-in-one server only. Scale-out — one Deployment per role
selected via the `SERVICES` env (`frontend`/`history`/`matching`/`worker`) — is a
future chart capability.

## Security

- Runs as nonroot (uid 1001), read-only root filesystem, all capabilities dropped.
- Image pinned by digest and cosign-signed (keyless):

```bash
cosign verify ghcr.io/quenchworks/images/temporal \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# postgres-ha-stack

Highly available PostgreSQL with pooling and metrics in one install:
- **PostgreSQL 18**, a 3-node Patroni cluster. Patroni elects the leader through the
  Kubernetes API (no etcd) and fails over on its own.
- **PgBouncer**, pooling in front of whichever node is leader.
- **postgres_exporter** against the leader.
- **Prometheus**, which discovers the exporter in the release namespace.
- **Grafana**, with the Prometheus datasource and the postgres_exporter "Postgres
  Overview" dashboard provisioned.

Every component is a QuenchWorks chart or image: hardened, nonroot, 0-CVE, pinned by
digest and cosign-signed.

## Install

```sh
helm install db oci://ghcr.io/quenchworks/charts/postgres-ha-stack
kubectl get secret postgres-ha-auth -o jsonpath='{.data.postgres-password}' | base64 -d
```

Point applications at `postgres-ha-pgbouncer:6432`, database `appdb`, user `postgres`.

| Service | Port | Use |
|---|---|---|
| `postgres-ha-pgbouncer` | 6432 | pooled connections to the leader (use this) |
| `postgres-ha-primary` | 5432 | the leader, direct |
| `postgres-ha-replica` | 5432 | the standbys, read-only |

`kubectl exec postgres-ha-0 -c postgresql -- patronictl list` shows the cluster.

## How the pieces connect

- **Fixed names.** The subcharts take their backend host as a value, not a template,
  so every object is named `postgres-ha-*` (and Prometheus and Grafana are
  `<release>-prometheus` and `<release>-grafana`). Install one stack per namespace.
- **One credential.** The stack renders a single superuser password into two Secrets
  in the same pass. `postgres-ha-auth` holds it with the replication password, and
  `postgres-ha-userlist` is PgBouncer's userlist. Both are read back on upgrade, so
  they keep matching the running cluster. Set `auth.password` to choose it.
- **Exporter.** The Patroni StatefulSet has no exporter sidecar, so the stack runs
  postgres_exporter as its own Deployment against `postgres-ha-primary`. After a
  failover it reports the new leader.
- **Discovery.** Prometheus finds the exporter with `kubernetes_sd_configs` (role
  `endpoints`, own namespace) under a namespaced Role, with a projected
  ServiceAccount token.

## Values

Each component takes its own chart's values under its key: `postgresql.*`,
`pgbouncer.*`, `prometheus.*`, `grafana.*`. The stack's own keys:

| Key | Default | Meaning |
|---|---|---|
| `auth.password` | `""` | superuser password; empty generates one, kept across upgrades |
| `postgresql.auth.database` | `appdb` | created on first boot; keep `pgbouncer.externalDatabase.database` equal |
| `postgresql.ha.replicaCount` | `3` | cluster size; keep it odd |
| `pgbouncer.enabled` | `true` | the pooler |
| `exporter.enabled` | `true` | postgres_exporter |
| `prometheus.enabled` / `grafana.enabled` | `true` | the monitoring half |

The schema pins the values the wiring depends on:
- `postgresql.fullnameOverride: postgres-ha`
- `architecture: replication`
- `auth.existingSecret: postgres-ha-auth`

## Release gate

On kind, the gate runs these checks:
1. It installs the full stack and requires exactly one Patroni leader with a
   streaming replica.
2. It writes through PgBouncer and reads the row back from a replica.
3. It deletes the leader and requires a new leader, then another successful write
   through PgBouncer.
4. It requires `pg_up == 1` in Prometheus, per-database stats for `appdb`, the
   provisioned dashboard, and a query through Grafana's datasource.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

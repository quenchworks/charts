# postgres-exporter

[postgres_exporter](https://github.com/prometheus-community/postgres_exporter) as a standalone Deployment: it connects to one PostgreSQL server
and serves its statistics as Prometheus metrics on port 9187. Runs on the QuenchWorks
postgres-exporter image (built from source on Wolfi, nonroot, 0 fixable CVEs, cosign-signed, pinned by
digest).

The QuenchWorks postgresql chart (and postgres-documentdb, timescaledb, postgres-ha-stack) can run this exporter as a sidecar (metrics.enabled); use this chart for a server those charts do not manage, such as a managed database.

## Install

The password is read from an existing Secret, never from a chart value:

```sh
kubectl create secret generic postgres-exporter-auth --from-literal=password='...'
helm install postgres-exporter oci://ghcr.io/quenchworks/charts/postgres-exporter \
  --set target.address=my-db:5432 \
  --set auth.username=postgres \
  --set auth.existingSecret=postgres-exporter-auth
kubectl port-forward svc/postgres-exporter 9187 & curl -s localhost:9187/metrics | grep '^pg_up '
```

`pg_up 1` means the exporter reached and authenticated to the server.

## Values

| Key | Default | Meaning |
|---|---|---|
| `target.address` | required | host:port |
| `auth.username` | `postgres` | login role (pg_monitor is enough) |
| `auth.existingSecret` (required) | | Secret holding the password |
| `auth.existingSecretPasswordKey` | `password` | its key |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `extraArgs` | `[]` | other `postgres_exporter` flags |

## Release gate

The gate installs this repository's postgresql chart in kind, points the exporter at it with the
password from that chart's Secret, and passes only when `/metrics` reports `pg_up 1`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

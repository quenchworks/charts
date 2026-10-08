# mysqld-exporter

[mysqld_exporter](https://github.com/prometheus/mysqld_exporter) as a standalone Deployment: it connects to one MySQL / MariaDB server
and serves its statistics as Prometheus metrics on port 9104. Runs on the QuenchWorks
mysqld-exporter image (built from source on Wolfi, nonroot, 0 fixable CVEs, cosign-signed, pinned by
digest).

The QuenchWorks mysql and mariadb charts (and mysql-ha-stack, mariadb-operator) can run this exporter as a sidecar (metrics.enabled); use this chart for a server those charts do not manage, such as a managed database.

## Install

The password is read from an existing Secret, never from a chart value:

```sh
kubectl create secret generic mysqld-exporter-auth --from-literal=password='...'
helm install mysqld-exporter oci://ghcr.io/quenchworks/charts/mysqld-exporter \
  --set target.address=my-db:3306 \
  --set auth.username=exporter \
  --set auth.existingSecret=mysqld-exporter-auth
kubectl port-forward svc/mysqld-exporter 9104 & curl -s localhost:9104/metrics | grep '^mysql_up '
```

`mysql_up 1` means the exporter reached and authenticated to the server.

## Values

| Key | Default | Meaning |
|---|---|---|
| `target.address` | required | host:port |
| `auth.username` | `exporter` | user with PROCESS, REPLICATION CLIENT and SELECT grants |
| `auth.existingSecret` (required) | | Secret holding the password |
| `auth.existingSecretPasswordKey` | `password` | its key |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `extraArgs` | `[]` | other `mysqld_exporter` flags |

## Release gate

The gate installs this repository's mysql chart in kind, points the exporter at it with the
password from that chart's Secret, and passes only when `/metrics` reports `mysql_up 1`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

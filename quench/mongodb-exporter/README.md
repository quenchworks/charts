# mongodb-exporter

[mongodb_exporter](https://github.com/percona/mongodb_exporter) as a standalone Deployment: it connects to one MongoDB server
and serves its statistics as Prometheus metrics on port 9216. Runs on the QuenchWorks
mongodb-exporter image (built from source on Wolfi, nonroot, 0 fixable CVEs, cosign-signed, pinned by
digest).

The QuenchWorks mongodb chart can run this exporter as a sidecar (metrics.enabled); use this chart for a server that chart does not manage, such as a managed database.

## Install

The password is read from an existing Secret, never from a chart value:

```sh
kubectl create secret generic mongodb-exporter-auth --from-literal=password='...'
helm install mongodb-exporter oci://ghcr.io/quenchworks/charts/mongodb-exporter \
  --set target.address=my-db:27017 \
  --set auth.username=exporter \
  --set auth.existingSecret=mongodb-exporter-auth
kubectl port-forward svc/mongodb-exporter 9216 & curl -s localhost:9216/metrics | grep '^mongodb_up '
```

`mongodb_up 1` means the exporter reached and authenticated to the server.

## Values

| Key | Default | Meaning |
|---|---|---|
| `target.address` | required | host:port |
| `auth.username` | `exporter` | user with the clusterMonitor role (and read on local) |
| `auth.existingSecret` (required) | | Secret holding the password |
| `auth.existingSecretPasswordKey` | `password` | its key |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `extraArgs` | `[]` | other `mongodb_exporter` flags |

## Release gate

The gate installs this repository's mongodb chart in kind, points the exporter at it with the
password from that chart's Secret, and passes only when `/metrics` reports `mongodb_up 1`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

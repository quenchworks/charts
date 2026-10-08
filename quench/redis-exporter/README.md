# redis-exporter

[redis_exporter](https://github.com/oliver006/redis_exporter) as a standalone Deployment: it connects to one Redis / Valkey server
and serves its statistics as Prometheus metrics on port 9121. Runs on the QuenchWorks
redis-exporter image (built from source on Wolfi, nonroot, 0 fixable CVEs, cosign-signed, pinned by
digest).

The QuenchWorks redis and valkey charts can run this exporter as a sidecar (metrics.enabled); use this chart for a server those charts do not manage, or to scrape several from one place.

## Install

The password is read from an existing Secret, never from a chart value:

```sh
kubectl create secret generic redis-exporter-auth --from-literal=password='...'
helm install redis-exporter oci://ghcr.io/quenchworks/charts/redis-exporter \
  --set target.address=redis://my-redis:6379 \
  --set auth.username=default \
  --set auth.existingSecret=redis-exporter-auth
kubectl port-forward svc/redis-exporter 9121 & curl -s localhost:9121/metrics | grep '^redis_up '
```

`redis_up 1` means the exporter reached and authenticated to the server.

## Values

| Key | Default | Meaning |
|---|---|---|
| `target.address` | required | redis://host:6379 (rediss:// for TLS) |
| `auth.username` | `` | ACL user (Redis 6+); empty uses the default user |
| `auth.existingSecret` (optional; omit for a server without a password) | | Secret holding the password |
| `auth.existingSecretPasswordKey` | `password` | its key |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `extraArgs` | `[]` | other `redis_exporter` flags |

## Release gate

The gate installs this repository's redis chart in kind, points the exporter at it with the
password from that chart's Secret, and passes only when `/metrics` reports `redis_up 1`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

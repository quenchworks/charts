# Quenchworks Trickster

Hardened [Trickster](https://github.com/trickstercache/trickster), a caching reverse proxy for
time-series databases and HTTP origins. Put it between dashboards and Prometheus, InfluxDB or
ClickHouse: it caches range-query results and fetches only the new tail of each window, so
dashboards that refresh every few seconds stop re-running the whole query. The image is built
from source, runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install tsc oci://ghcr.io/quenchworks/charts/trickster \
  --set config.backends.default.origin_url=http://prometheus-server.monitoring:9090
```

Then point the Grafana data source at `http://tsc-trickster:8480`.

## Configuration

`config` is Trickster's own config file as YAML and goes to Trickster unchanged. Keep the
default listener (8480) and metrics port (8481); the Service and probes use them.

```yaml
config:
  backends:
    prom:
      provider: prometheus
      origin_url: http://prometheus-server:9090
    influx:
      provider: influxdb
      origin_url: http://influxdb:8086
  caches:
    default:
      provider: redis
      redis:
        endpoint: redis-master:6379
```

| Key | Default | What it does |
|---|---|---|
| `config` | one Prometheus backend, 256 MiB memory cache | Trickster's config file |
| `service.port` | `8480` | Service port for the proxy |
| `extraArgs` | `[]` | More `trickster` arguments |

The memory cache lives in each pod; size `resources.limits.memory` above the cache size, or use
a Redis cache to share it across replicas.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/trickster \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

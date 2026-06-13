# Quenchworks OpenTelemetry Collector

Hardened [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector)
(the official `otelcol-contrib` distribution) on a minimal, nonroot, 0-CVE image
pinned by digest. Built from source on Wolfi with the upstream `v0.154.0` contrib
manifest, so it has component parity with the official release.

Ships in **gateway mode**: a standalone Deployment that receives OTLP, processes
it, and exports it. A per-node `agent` DaemonSet variant is a tracked follow-up.

## Install

```bash
helm install otelcol oci://ghcr.io/quenchworks/charts/otel-collector
```

## Send telemetry

The Service exposes the OTLP ingest ports. Point any OpenTelemetry SDK, agent, or
upstream collector at:

```
gRPC: otelcol-otel-collector:4317
HTTP: http://otelcol-otel-collector:4318
```

e.g. `OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcol-otel-collector:4318`.

## The default exporter is `debug` (logs, does not forward)

Out of the box the pipelines export to the `debug` exporter, which **logs**
received telemetry to the collector's stdout and forwards it nowhere:

```bash
kubectl logs deploy/otelcol-otel-collector
```

This keeps the chart self-contained. Add a real exporter before production use.

## Override the config

The entire collector config lives in the `config` value, is rendered into a
ConfigMap, mounted at `/etc/otelcol/config.yaml`, and passed as `--config`. The
image ships **no** default config, so `config` is the whole configuration.
Override it wholesale:

```yaml
config:
  receivers:
    otlp:
      protocols:
        grpc: { endpoint: 0.0.0.0:4317 }
        http: { endpoint: 0.0.0.0:4318 }
  processors:
    memory_limiter: { check_interval: 5s, limit_percentage: 80, spike_limit_percentage: 25 }
    batch: {}
  exporters:
    otlp:
      endpoint: my-backend:4317     # forward to a real OTLP backend
  extensions:
    health_check: { endpoint: 0.0.0.0:13133 }
  service:
    extensions: [health_check]
    pipelines:
      traces:  { receivers: [otlp], processors: [memory_limiter, batch], exporters: [otlp] }
      metrics: { receivers: [otlp], processors: [memory_limiter, batch], exporters: [otlp] }
      logs:    { receivers: [otlp], processors: [memory_limiter, batch], exporters: [otlp] }
    telemetry:
      metrics:
        readers:
          - pull: { exporter: { prometheus: { host: 0.0.0.0, port: 8888 } } }
```

`helm upgrade` rolls the pod on the config checksum. Keep `memory_limiter` first
in every pipeline and keep the `health_check` extension on :13133 (the probes
depend on it).

## Scrape the collector's own metrics

The collector exposes its internal Prometheus metrics on `:8888`:

```bash
curl http://otelcol-otel-collector:8888/metrics
```

Add a scrape job in Prometheus (`service.exposeMetrics` is `true` by default).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/otel-collector \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/otel-collector` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `mode` | `deployment` | Gateway mode. DaemonSet agent is a follow-up. |
| `replicaCount` | `1` | Stateless pipeline; scale out for ingest throughput. |
| `config` | OTLP -> memory_limiter,batch -> debug | The full collector config (templated to `/etc/otelcol/config.yaml`). |
| `service.ports.otlpGrpc` | `4317` | OTLP gRPC ingest. |
| `service.ports.otlpHttp` | `4318` | OTLP HTTP ingest. |
| `service.ports.metrics` | `8888` | Collector's own Prometheus `/metrics`. |
| `service.ports.health` | `13133` | `health_check` extension (`GET /` -> 200). |
| `service.exposeMetrics` | `true` | Publish `:8888` on the Service for scraping. |
| `service.exposeHealth` | `false` | Publish `:13133` on the Service. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped; `/tmp` is a writable emptyDir. The collector has **no built-in
authentication** — the NetworkPolicy is the trust boundary. Front the OTLP
endpoints with an authenticating proxy or mTLS if you expose them beyond the
cluster.

## Notes

Gateway mode (Deployment). The default `debug` exporter logs rather than forwards
telemetry; add a real exporter for production. Depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

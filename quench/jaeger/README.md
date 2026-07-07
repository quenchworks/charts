# Quenchworks Jaeger

Hardened [Jaeger](https://github.com/jaegertracing/jaeger) v2 all-in-one
distributed tracing on a minimal, nonroot, 0-CVE image, pinned by digest.

Jaeger v2 is built on the OpenTelemetry Collector: this chart runs the
all-in-one binary (collector + query + web UI in one process) with native OTLP
ingestion.

## Install

```sh
helm install tracing oci://ghcr.io/quenchworks/charts/jaeger
```

Send OpenTelemetry traces to the OTLP receivers and open the UI over a
port-forward:

```sh
kubectl port-forward svc/tracing-jaeger 16686:16686
# browse http://127.0.0.1:16686
```

| Service port | Default | Purpose |
|--------------|---------|---------|
| query UI/API | `16686` | Jaeger web UI + HTTP query API |
| OTLP gRPC    | `4317`  | OTLP trace ingestion (gRPC) |
| OTLP HTTP    | `4318`  | OTLP trace ingestion (HTTP) |

Liveness/readiness use the healthcheck extension on container port `13133`
(`GET /status`).

## Storage

By default the chart runs with **in-memory** storage: traces live in RAM only,
are lost on restart, and the install must stay at a single replica. This is fine
for demos and local development, not for production.

For a durable, scalable deployment, set `config.yaml` to a full Jaeger v2
(OpenTelemetry-collector) configuration backed by a real store
(badger / elasticsearch / cassandra). It is written to a ConfigMap, mounted at
`/etc/jaeger/config.yaml`, and passed to the binary via `--config`. Point
`config.existingConfigMap` at an externally-managed ConfigMap (key `config.yaml`)
to use that instead.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/jaeger` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | in-memory storage is not shared; do not scale |
| `config.yaml` | `""` | inline Jaeger v2 config (mounted, passed via `--config`) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `config.yaml`, wins) |
| `extraArgs` | `[]` | appended to the `jaeger` command |
| `service.type` | `ClusterIP` | |
| `service.ports.query` | `16686` | query UI/API |
| `service.ports.otlpGrpc` | `4317` | OTLP gRPC receiver |
| `service.ports.otlpHttp` | `4318` | OTLP HTTP receiver |

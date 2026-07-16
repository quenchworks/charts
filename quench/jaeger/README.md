# Quenchworks Jaeger

Hardened [Jaeger](https://github.com/jaegertracing/jaeger) v2 all-in-one
distributed tracing on a minimal, nonroot, 0-CVE image, cosign-signed and pinned
by digest. Jaeger v2 is built on the OpenTelemetry Collector, so this chart runs
the all-in-one binary (collector + query + web UI in one process) with native
OTLP ingestion. The container runs nonroot on a read-only root filesystem with
all capabilities dropped, and the chart pins the image by its signed digest,
never a tag.

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

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/jaeger \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```sh
gh attestation verify oci://ghcr.io/quenchworks/images/jaeger --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/jaeger` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Fixed at 1: in-memory storage is not shared, so do not scale. |
| `config.yaml` | `""` | Inline Jaeger v2 config. Written to a ConfigMap, mounted at `/etc/jaeger/config.yaml`, passed via `--config`. Empty uses the baked-in in-memory default. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `config.yaml`) instead; wins over `config.yaml`. |
| `extraArgs` | `[]` | Extra flags appended to the `jaeger` command. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.ports.query` | `16686` | Query UI + HTTP API. |
| `service.ports.otlpGrpc` | `4317` | OTLP gRPC receiver. |
| `service.ports.otlpHttp` | `4318` | OTLP HTTP receiver. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A Deployment runs the all-in-one binary: collector, query service and web UI in
one process. Three ports are published on the Service: query UI/API (`16686`),
OTLP gRPC (`4317`) and OTLP HTTP (`4318`). Liveness and readiness use the
healthcheck extension on container port `13133` (`GET /status`), which is not
exposed on the Service.

With the default in-memory storage the process holds spans in RAM only: they are
lost on restart, and the install cannot be scaled because each replica would keep
its own disjoint traces (the schema caps `replicaCount` at 1). For a durable,
scalable deployment, set `config.yaml` to a full Jaeger v2
(OpenTelemetry-collector) config backed by a real store (badger, elasticsearch or
cassandra). The container runs nonroot on a read-only root filesystem; a writable
`emptyDir` is mounted at `/tmp` for scratch.

## Configuration examples

Durable Badger storage on a mounted volume (pair with `extraVolumes` /
`extraVolumeMounts` for the data path):

```yaml
config:
  yaml: |
    service:
      extensions: [jaeger_storage, jaeger_query, healthcheckv2]
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [jaeger_storage_exporter]
    extensions:
      healthcheckv2:
        use_v2: true
        http:
          endpoint: 0.0.0.0:13133
      jaeger_storage:
        backends:
          default:
            badger:
              directories:
                keys: /data/keys
                values: /data/values
      jaeger_query:
        storage:
          traces: default
      jaeger_storage_exporter:
        trace_storage: default
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
```

Quieter logs via extra flags:

```yaml
extraArgs:
  - "--set=service.telemetry.logs.level=warn"
```

## Uninstall

```sh
helm uninstall tracing
```

The workload is stateless with the default in-memory store and holds no PVCs.

## Notes

The default in-memory topology is single-node and ephemeral, fit for demos and
local development. Durable, scalable storage backends are configured through
`config.yaml`. The chart depends on the `quench-common` library chart, pulled
from `oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as
nonroot on a read-only root filesystem with all capabilities dropped, and the
image is pinned by digest.

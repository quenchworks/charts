# Quenchworks tracing-stack

A hardened, operator-free distributed-tracing bundle: **Tempo** (trace store and
query), **Grafana** (Tempo pre-wired as the default datasource, plus a tracing
overview dashboard), and an **OpenTelemetry Collector** gateway that receives
OTLP from your applications and forwards spans to Tempo. No operator, no CRDs.
Every component image is QuenchWorks-hardened: minimal, nonroot (uid 1001), 0-CVE,
pinned by digest and cosign-signed (keyless / Sigstore) with an SPDX SBOM and SLSA
provenance, running on a read-only root filesystem with all capabilities dropped.

Your apps send OTLP traces to one endpoint (`<release>-otel-collector:4317`), and
you explore them in Grafana through Explore -> Tempo.

| Component | Role | Source |
|-----------|------|--------|
| **Tempo** | trace ingest, storage, and query (TraceQL) | `quench/tempo` subchart |
| **Grafana** | Tempo datasource + tracing overview dashboard | `quench/grafana` subchart |
| **OpenTelemetry Collector** | OTLP ingress gateway: receives spans, batches, forwards to Tempo | templated inline |

## Install

```bash
helm install trace oci://ghcr.io/quenchworks/charts/tracing-stack
```

Open Grafana and read the generated admin password:

```bash
kubectl get secret trace-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/trace-grafana 3000:3000
# http://127.0.0.1:3000  (user: admin) — the "Tempo" datasource is the default.
# Go to Explore -> Tempo to search traces.
```

Point your application's OTLP exporter at the collector Service:

| Protocol | Endpoint |
|----------|----------|
| OTLP gRPC | `<release>-otel-collector:4317` |
| OTLP HTTP | `http://<release>-otel-collector:4318` |

With the OpenTelemetry SDK environment convention:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://trace-otel-collector:4318
OTEL_SERVICE_NAME=my-app
```

Use the `.<namespace>.svc` suffix when the app is in a different namespace. Apps
may also send OTLP straight to `<release>-tempo:4317` / `:4318` (Tempo runs its
own OTLP receivers); the collector gateway is the recommended ingress because it
gives you batching, memory limiting, and one place to add processors/exporters
(sampling, attribute scrubbing, fan-out to a second backend) without touching
your apps.

## Verify the image

The stack bundles three images. Each is cosign-signed keyless and pinned by
digest:

```bash
cosign verify ghcr.io/quenchworks/images/tempo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify ghcr.io/quenchworks/images/grafana \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify ghcr.io/quenchworks/images/otel-collector \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/tempo --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/grafana --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/otel-collector --owner quenchworks
```

## Values

| Value | Default | Notes |
|-------|---------|-------|
| `tempo.enabled` | `true` | Toggle the Tempo subchart. |
| `grafana.enabled` | `true` | Toggle the Grafana subchart. |
| `otelCollector.enabled` | `true` | Toggle the inline collector gateway. |
| `tempo.persistence.size` | `8Gi` | Tempo trace blocks + WAL PVC. |
| `grafana.auth.adminPassword` | `""` | Generated (24 chars) into the grafana Secret when empty. |
| `dashboards.enabled` | `true` | Provision the bundled dashboard (`false` = none). |
| `dashboards.include.tempo-operational` | `true` | Per-dashboard toggle. |
| `otelCollector.image` | `ghcr.io/quenchworks/images/otel-collector` | Collector image repository. |
| `otelCollector.digest` | (pinned) | Collector image digest, never a tag. |
| `otelCollector.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `otelCollector.replicaCount` | `1` | Stateless gateway; scale for OTLP ingest. |
| `otelCollector.config` | OTLP in -> batch -> OTLP to Tempo | The whole collector config (rendered via `tpl`). |
| `otelCollector.ports.otlpGrpc` | `4317` | OTLP gRPC ingest port apps send to. |
| `otelCollector.ports.otlpHttp` | `4318` | OTLP HTTP ingest port apps send to. |
| `otelCollector.ports.metrics` | `8888` | Collector's own Prometheus metrics port. |
| `otelCollector.ports.health` | `13133` | health_check extension port (probes). |
| `otelCollector.exposeMetrics` | `true` | Expose the `:8888` metrics port on the Service. |
| `otelCollector.resources` | `100m/128Mi` .. `1/512Mi` | Collector CPU / memory requests and limits. |

Tempo and Grafana values pass straight through under their block (`tempo:`,
`grafana:`); see each component chart's `values.yaml` for the full surface. The
shared `quench-common` knobs (scheduling, probes, sidecars, init containers,
extra env/volumes, security contexts, update strategy) are set per component
inside the `tempo:` and `grafana:` blocks. See all options with:

```bash
helm show values oci://ghcr.io/quenchworks/charts/tracing-stack
```

## Architecture

The umbrella owns a thin glue layer; Tempo and Grafana pass through to their
component charts. Data flows in one direction from your apps and the other from
Grafana:

```
your app --(OTLP)--> <release>-otel-collector:4317 (gRPC) / :4318 (HTTP)
                         |  traces pipeline: memory_limiter + batch
                         v
                     OTLP --> <release>-tempo:4317
                         |
                         v
   Grafana --(Tempo datasource @ http://<release>-tempo:3200)--> Explore -> Tempo
```

Bundled subcharts and glue:

- **Tempo** (`quench/tempo` subchart) — ships single-binary (`-target=all`) with a
  filesystem trace backend. Its HTTP API (query, `/ready`, `/metrics`) is on
  `:3200` and it runs its own OTLP receivers on `:4317` (gRPC) / `:4318` (HTTP).
- **Grafana** (`quench/grafana` subchart) — the umbrella renders a fixed-name
  ConfigMap (`tracing-stack-datasources`) with a Tempo datasource (uid `tempo`,
  `access: proxy`, `isDefault: true`) pointing at `http://<release>-tempo:3200`,
  and mounts it into Grafana's provisioning directory via `grafana.extraVolumes`;
  `grafana.datasources` stays empty. Grafana runs stateless here (persistence off)
  so datasources and dashboards re-provision from ConfigMaps on every boot, which
  avoids admin-password drift on reinstall.
- **OpenTelemetry Collector** (inline) — templated directly by this umbrella
  (`templates/otel-collector.yaml`: ServiceAccount + config ConfigMap + Deployment
  + Service) rather than pulled in as the `otel-collector` subchart. The subchart
  renders its config via `toYaml`, which cannot template the release name into the
  exporter endpoint; inlining lets the traces pipeline export to
  `<release>-tempo:4317`. `otelCollector.config` is the entire collector
  configuration and is rendered through `tpl`, so it carries the release name.
  The container runs nonroot 1001 on a read-only root filesystem (only `/tmp` is
  writable), with liveness and readiness probing the health_check extension
  (`GET /` on `:13133`).
- **Dashboards** — one tracing overview dashboard ships in `dashboards/`, rendered
  into a ConfigMap and provisioned through a Grafana file provider (same mount
  mechanism as the datasource). No Grafana sidecar image required.

There is no OpenTelemetry Operator and no CRDs. You lose CRD-driven collector
config (`OpenTelemetryCollector` CRs) and gain a smaller, hardened footprint with
nothing cluster-scoped to upgrade. The collector is a plain Deployment with its
config in a ConfigMap that you edit in values.

The fixed-name datasource and dashboard ConfigMaps mean one tracing-stack per
namespace. To collect traces from apps across namespaces, point those apps at the
collector's fully-qualified Service name
(`<release>-otel-collector.<namespace>.svc:4317`).

## Configuration examples

Toggle the bundled dashboard off (Grafana still installs, just no bundled
dashboard):

```yaml
dashboards:
  enabled: false
```

Scale OTLP ingest and grow the Tempo volume:

```yaml
otelCollector:
  replicaCount: 3
tempo:
  persistence:
    size: 50Gi
```

Add a sampling processor to the collector pipeline (override `otelCollector.config`
wholesale; keep `memory_limiter` first and the Tempo exporter targeting
`{{ .Release.Name }}-tempo`):

```yaml
otelCollector:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:{{ .Values.otelCollector.ports.otlpGrpc }}
          http:
            endpoint: 0.0.0.0:{{ .Values.otelCollector.ports.otlpHttp }}
    processors:
      memory_limiter:
        check_interval: 5s
        limit_percentage: 80
        spike_limit_percentage: 25
      probabilistic_sampler:
        sampling_percentage: 10
      batch: {}
    exporters:
      otlp/tempo:
        endpoint: {{ .Release.Name }}-tempo:4317
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, probabilistic_sampler, batch]
          exporters: [otlp/tempo]
```

To add your own dashboard, import JSON through the Grafana UI, or add files to
`dashboards/` and re-release. Bind trace panels to the provisioned `tempo`
datasource uid.

## Uninstall

```bash
helm uninstall trace
```

This removes everything the chart created. No CRDs are installed, so there is
nothing to clean up afterwards. The Tempo and Grafana PersistentVolumeClaims are
retained by Helm convention — delete them by hand if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=trace
```

## Notes

- Requires Kubernetes 1.23+ and Helm 3.8+ (OCI support).
- Operator-free and CRD-free; nothing cluster-scoped is created, so upgrades never
  require a separate CRD apply step.
- The bundled Tempo dashboard ships no synthetic data — it populates once your apps
  emit traces. The richer day-to-day view is Explore -> Tempo (search by service
  name, span attributes, duration, or look up a trace ID and view the waterfall).
  Tempo's own operational metrics (`tempo_*`) are on `<release>-tempo:3200/metrics`
  and the collector's on `:8888/metrics`; scrape those with a metrics stack (e.g.
  the QuenchWorks `observability-stack`) and add a Prometheus datasource to chart
  ingest/query rates.
- Tempo ships single-binary with a filesystem trace backend, which is fine for kind
  and small/moderate ingest. Scale-out (distributor / ingester / querier / compactor
  split backed by an object store) is a tracked follow-up; see `quench/tempo` values.
- In-cluster OTLP between the collector and Tempo is plaintext (TLS insecure); front
  Tempo with mTLS or a service mesh if you need wire encryption.
- Every component runs nonroot (uid 1001) on a read-only root filesystem with all
  capabilities dropped, and every image is pinned by digest. The chart's Tempo and
  Grafana subcharts are pulled from `oci://ghcr.io/quenchworks/charts`.
```

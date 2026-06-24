# tracing-stack

A hardened, **operator-free** distributed-tracing bundle: **Tempo** (trace store +
query), **Grafana** (Tempo pre-wired as the default datasource, plus a tracing
overview dashboard), and an **OpenTelemetry Collector** gateway that receives OTLP
from your applications and forwards spans to Tempo. No operator, no CRDs.

Your apps send OTLP traces to one endpoint (`<release>-otel-collector:4317`), and
you explore them in Grafana through **Explore → Tempo**. Every component image is
QuenchWorks-hardened: built from source on Wolfi, nonroot (uid 1001), 0 fixable
CVEs, cosign-signed with an SBOM and SLSA provenance, and pinned by digest.

| Component | Role | Source |
|-----------|------|--------|
| **Tempo** | trace ingest, storage, and query (TraceQL) | `quench/tempo` |
| **Grafana** | Tempo datasource + tracing overview dashboard | `quench/grafana` |
| **OpenTelemetry Collector** | OTLP ingress gateway: receives spans, batches, forwards to Tempo | templated inline |

### Data flow

```
your app --(OTLP)--> <release>-otel-collector:4317 (gRPC) / :4318 (HTTP)
                         |  traces pipeline: memory_limiter + batch
                         v
                     OTLP --> <release>-tempo:4317
                         |
                         v
   Grafana --(Tempo datasource @ http://<release>-tempo:3200)--> Explore -> Tempo
```

Apps **may** also send OTLP straight to `<release>-tempo:4317` / `:4318` (Tempo runs
its own OTLP receivers). The collector gateway is the recommended ingress: it gives
you batching, memory limiting, and one place to add processors/exporters (sampling,
attribute scrubbing, fan-out to a second backend) without touching your apps.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+ (OCI support)

## Usage

The chart is distributed as an OCI artifact:

```sh
oci://ghcr.io/quenchworks/charts/tracing-stack
```

### Install

```sh
helm install trace oci://ghcr.io/quenchworks/charts/tracing-stack
```

Open Grafana and read the generated admin password:

```sh
kubectl get secret trace-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/trace-grafana 3000:3000
# http://127.0.0.1:3000  (user: admin) — the "Tempo" datasource is the default.
# Go to Explore -> Tempo to search traces.
```

### Uninstall

```sh
helm uninstall trace
```

This removes everything the chart created. **No CRDs are installed, so there is
nothing to clean up afterwards.** The Tempo and Grafana PersistentVolumeClaims are
retained by Helm convention; delete them by hand if you want the data gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=trace
```

### Upgrade

```sh
helm upgrade trace oci://ghcr.io/quenchworks/charts/tracing-stack
```

No CRDs, so upgrades never require a separate CRD apply step.

## How apps send traces

Point your application's OTLP exporter at the collector Service:

| Protocol | Endpoint |
|----------|----------|
| OTLP gRPC | `<release>-otel-collector:4317` |
| OTLP HTTP | `http://<release>-otel-collector:4318` |

With the OpenTelemetry SDK environment convention:

```sh
OTEL_EXPORTER_OTLP_ENDPOINT=http://trace-otel-collector:4318
OTEL_SERVICE_NAME=my-app
```

(Use the `.<namespace>.svc` suffix when the app is in a different namespace.) The
collector batches spans and forwards them to Tempo over OTLP gRPC.

## How it's wired

The umbrella owns a thin glue layer; Tempo and Grafana pass straight through to
their component charts.

- **Grafana Tempo datasource** — the umbrella renders a fixed-name ConfigMap
  (`tracing-stack-datasources`) with a Tempo datasource (uid `tempo`,
  `access: proxy`, `isDefault: true`) pointing at `http://<release>-tempo:3200`,
  and mounts it into Grafana's provisioning directory via `grafana.extraVolumes`.
  `grafana.datasources` stays empty. **Fixed names ⇒ run one tracing-stack per
  namespace.**
- **OpenTelemetry Collector (inline)** — templated directly by this umbrella
  (`templates/otel-collector.yaml`: ServiceAccount + config ConfigMap + Deployment +
  Service) rather than pulled in as the `otel-collector` subchart. The subchart
  renders its config via `toYaml`, which cannot template the release name into the
  exporter endpoint; inlining lets the traces pipeline export to
  `{{ .Release.Name }}-tempo:4317`. The `otelCollector.config` value is the entire
  collector configuration and is rendered through `tpl`, so it carries the release
  name. (Same inlining technique `observability-stack` uses for kube-state-metrics.)
- **Dashboards** — one tracing overview dashboard ships in `dashboards/`, rendered
  into a ConfigMap and provisioned through a Grafana file provider (same mount
  mechanism as the datasource). No Grafana sidecar image required.

### Why no operator / no collector subchart?

There is no OpenTelemetry Operator and no CRDs here — the collector is a plain
Deployment with its config in a ConfigMap that you edit in values. You lose
CRD-driven collector config (`OpenTelemetryCollector` CRs) and gain a smaller,
simpler, hardened footprint with nothing cluster-scoped to upgrade. The collector
is inlined (not the published `otel-collector` chart) purely so its Tempo exporter
endpoint can carry the release name; it is otherwise the same hardened container.

## Dashboards

One dashboard ships and provisions automatically:

| Dashboard | Shows | Needs |
|-----------|-------|-------|
| Tempo / Tracing Overview | a TraceQL search table over the Tempo datasource + guidance | Tempo + trace volume |

The richer day-to-day view is **Explore → Tempo** (search by service name, span
attributes, duration, or look up a trace ID and view the waterfall). The bundled
dashboard does **not** ship synthetic data — it populates once your apps emit
traces. Tempo's own operational metrics (`tempo_*`) are exposed on
`<release>-tempo:3200/metrics` and the collector's on `:8888/metrics`; scrape those
with a metrics stack (e.g. the QuenchWorks `observability-stack`) and add a
Prometheus datasource to chart ingest/query rates.

Toggle the bundled dashboard:

```yaml
# All (default): nothing to set.

# None: Grafana installs with no bundled dashboard.
dashboards:
  enabled: false
```

To add your own, import JSON through the Grafana UI (persisted on the Grafana PVC),
or add files to `dashboards/` and re-release. Bind trace panels to the provisioned
`tempo` datasource uid.

## Multiple releases

The fixed-name datasource and dashboard ConfigMaps mean **one tracing-stack per
namespace**. To collect traces from apps across namespaces, point those apps at the
collector's fully-qualified Service name
(`<release>-otel-collector.<namespace>.svc:4317`).

## Scaling

- **Collector** — the gateway pipeline is stateless; raise `otelCollector.replicaCount`
  to scale OTLP ingest behind the ClusterIP Service.
- **Tempo** — ships single-binary (`-target=all`) with a filesystem trace backend.
  That is fine for kind and small/moderate ingest. Scale-out (distributor / ingester
  / querier / compactor split backed by an object store) is a tracked follow-up; see
  `quench/tempo` values.

## Configuration

See all options with:

```sh
helm show values oci://ghcr.io/quenchworks/charts/tracing-stack
```

### Key values

| Value | Default | Notes |
|-------|---------|-------|
| `tempo.enabled` / `grafana.enabled` / `otelCollector.enabled` | `true` | per-component toggles |
| `tempo.persistence.size` | `8Gi` | Tempo trace blocks + WAL PVC |
| `grafana.auth.adminPassword` | `""` | generated (24 chars) into the grafana Secret when empty |
| `dashboards.enabled` | `true` | provision the bundled dashboard (`false` = none) |
| `dashboards.include.tempo-operational` | `true` | per-dashboard toggle |
| `otelCollector.config` | OTLP in → batch → OTLP to Tempo | the whole collector config (rendered via `tpl`) |
| `otelCollector.ports.otlpGrpc` / `otlpHttp` | `4317` / `4318` | OTLP ingest ports apps send to |
| `otelCollector.exposeMetrics` | `true` | expose the collector's `:8888` metrics on the Service |
| `otelCollector.digest` | (pinned) | otel-collector image digest |

Tempo and Grafana values pass through under their block (`tempo:`, `grafana:`); see
each component chart's `values.yaml` for the full surface.

## Security posture

- Operator-free, CRD-free; nothing cluster-scoped is created.
- Clean stack: **no host access**. Tempo, Grafana and the collector all run nonroot
  (uid 1001) with a read-only root filesystem and all Linux capabilities dropped.
- All images built from source on Wolfi, 0 fixable CVEs, cosign-signed with SPDX
  SBOM + SLSA provenance, pinned by digest.
- In-cluster OTLP between the collector and Tempo is plaintext (TLS insecure); front
  Tempo with mTLS or a service mesh if you need wire encryption.

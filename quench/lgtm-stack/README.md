# lgtm-stack

The full **LGTM** observability superset in one install — a hardened, **operator-free**
single pane over **metrics, logs, and traces**:

- **L**oki — log aggregation
- **G**rafana — the single pane (three pre-wired datasources)
- **T**empo — distributed tracing
- **M**etrics — **VictoriaMetrics** (Prometheus-compatible TSDB)

plus the glue that makes it work out of the box: an **OpenTelemetry Collector** (OTLP
trace ingest), **Vector** (log shipper), **Alertmanager** (alert routing),
**kube-state-metrics** and **node-exporter** (so the metrics dashboards populate). No
operator, no CRDs. Every component image is QuenchWorks-hardened: built from source on
Wolfi, nonroot (uid 1001), 0 fixable CVEs, cosign-signed with an SBOM and SLSA
provenance, and pinned by digest.

| Component | Role | Source |
|-----------|------|--------|
| **VictoriaMetrics** | Prometheus-compatible metrics store + embedded scraper (`promscrape`) | `quench/victoriametrics` |
| **Loki** | log ingest, storage, query (LogQL) | `quench/loki` |
| **Grafana** | single pane: 3 datasources + curated dashboards | `quench/grafana` |
| **Tempo** | trace ingest, storage, query (TraceQL) | `quench/tempo` |
| **Alertmanager** | alert routing / notification | `quench/alertmanager` |
| **OpenTelemetry Collector** | OTLP ingress gateway → Tempo | templated inline |
| **Vector** | per-node log shipper → Loki | templated inline |
| **kube-state-metrics** | cluster object metrics | templated inline |
| **node-exporter** | per-node host metrics | templated inline |

## Grafana — three datasources

This umbrella provisions all three datasources into Grafana via a fixed-name ConfigMap
(`lgtm-stack-datasources`) mounted through `grafana.extraVolumes` — so each URL can
carry the release name. Keep `grafana.datasources: []`.

| Datasource | Type | UID | URL |
|------------|------|-----|-----|
| **VictoriaMetrics** (default) | `prometheus` | `metrics` | `http://<release>-victoriametrics:8428` |
| **Loki** | `loki` | `loki` | `http://<release>-loki:3100` |
| **Tempo** | `tempo` | `tempo` | `http://<release>-tempo:3200` |

The Tempo datasource is wired with `tracesToLogs` (→ Loki uid `loki`) and
`tracesToMetrics` (→ VictoriaMetrics uid `metrics`) so you can jump from a span to its
logs and to service metrics.

### Data flow

```
your app --(prometheus.io/scrape annotations)--> VictoriaMetrics (promscrape pull)
your app --(stdout/stderr, automatic)--> Vector --> Loki :3100/loki/api/v1/push
your app --(OTLP :4317/:4318)--> OTel Collector --> Tempo :4317

         Grafana (single pane)
           ├─ VictoriaMetrics (uid metrics, default)  →  metrics dashboards
           ├─ Loki            (uid loki)              →  logs dashboard / Explore
           └─ Tempo           (uid tempo)             →  Explore → Tempo
```

## How metrics are ingested — VictoriaMetrics `promscrape` (pull)

VictoriaMetrics single-node ships an **embedded scraper** (vmagent-style). This chart
turns it on by passing `-promscrape.config=/etc/vm/scrape.yaml` through
`victoriametrics.config.extraArgs` and mounting a release-agnostic scrape config
(`templates/victoriametrics-scrape.yaml`, ConfigMap `lgtm-stack-vm-scrape`). The config
is Prometheus `scrape_configs` syntax and discovers targets at runtime via
`kubernetes_sd_configs` — **no service name is templated in**, so it is fully portable:

- **`kubernetes-pods`** — annotation-based: any pod annotated `prometheus.io/scrape:
  "true"` (honoring `prometheus.io/port` and `prometheus.io/path`). kube-state-metrics,
  node-exporter and the OTel Collector are all annotated, so they are picked up here.
- **`kubelet`** / **`cadvisor`** — the kubelet's own `/metrics` and `/metrics/cadvisor`
  via the apiserver proxy (container CPU/memory/net/fs without an extra DaemonSet).
- **`kubernetes-apiservers`** — control-plane `up` + apiserver request metrics.
- **`victoriametrics`** — VM scrapes its own `/metrics`.

> **Why pull, not `remote_write`?** A single scrape config is release-agnostic and
> needs no per-app push wiring — the same annotation contract the observability-stack
> uses. If you prefer **push**, add a metrics pipeline to the OTel Collector that
> `prometheusremotewrite`s to `http://<release>-victoriametrics:8428/api/v1/write` and
> drop the promscrape flag. Pull is the default because it is the lowest-friction path.

**RBAC.** The victoriametrics subchart creates its ServiceAccount
(`<release>-victoriametrics`, quench-common fullname) but grants it no cluster perms,
and hardcodes `automountServiceAccountToken: false`. So this umbrella:

1. Projects the SA token + CA + namespace into the in-cluster path via
   `victoriametrics.extraVolumes` (so `kubernetes_sd` can authenticate), and
2. Creates a **ClusterRole + binding** for the `<release>-victoriametrics` SA
   (`templates/victoriametrics-rbac.yaml`) with the same read perms the observability
   stack's Prometheus uses: `pods, nodes, nodes/metrics, nodes/proxy, services,
   endpoints` (get/list/watch) + `/metrics`.

## How logs are ingested — Vector (automatic)

**Nothing to do.** Vector runs as a DaemonSet (`templates/vector.yaml`), tailing every
pod's stdout/stderr on every node via its `kubernetes_logs` source and pushing to
`http://<release>-loki:3100/loki/api/v1/push`, labelled by `namespace / pod / container
/ node / stream`. It is templated inline (not the `quench/vector` component chart, which
can't template the release name into the Loki sink). Query your namespace in **Explore →
Loki**.

## How traces are ingested — OTLP → OTel Collector → Tempo

Point your apps at the collector gateway:

```
OTLP gRPC:  <release>-otel-collector:4317
OTLP HTTP:  http://<release>-otel-collector:4318
# e.g. OTEL_EXPORTER_OTLP_ENDPOINT=http://<release>-otel-collector:4318
```

The collector (templated inline) batches + memory-limits spans and forwards them OTLP
to `<release>-tempo:4317`. Apps **may** also send OTLP straight to `<release>-tempo`.
Explore traces in **Explore → Tempo**.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+ (OCI support)
- A default StorageClass (for the Loki/Tempo/Grafana/Alertmanager/VM PVCs; or disable
  persistence per component)

## Usage

```sh
helm install lgtm oci://ghcr.io/quenchworks/charts/lgtm-stack
```

Open Grafana and read the generated admin password:

```sh
kubectl get secret lgtm-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/lgtm-grafana 3000:3000
# http://127.0.0.1:3000  (user: admin) — VictoriaMetrics is the default datasource.
```

In Explore, switch between the three datasources; the bundled dashboards appear under
Dashboards on first boot.

## Dashboards

Toggle which curated dashboards are provisioned via `dashboards.include.<name>`. Metrics
dashboards bind datasource uid `metrics`; the logs dashboard binds uid `loki`.

| Dashboard | Binds | Populated by |
|-----------|-------|--------------|
| `node-exporter-full` | uid `metrics` | node-exporter |
| `kubernetes-cluster` | uid `metrics` | kubelet/cAdvisor + ksm |
| `kubernetes-cluster-monitoring` | uid `metrics` | kubelet/cAdvisor + ksm |
| `kube-state-metrics-v2` | uid `metrics` | kube-state-metrics |
| `loki-kubernetes-logs` | uid `loki` | Vector → Loki |

```yaml
dashboards:
  enabled: true            # false => Grafana installs with no bundled dashboards
  include:
    node-exporter-full: true
    kubernetes-cluster: true
    kubernetes-cluster-monitoring: true
    kube-state-metrics-v2: true
    loki-kubernetes-logs: true
```

## Key values

| Value | Default | Notes |
|-------|---------|-------|
| `victoriametrics.enabled` | `true` | the "M". Prometheus-compatible, default datasource. |
| `loki.enabled` | `true` | the "L". |
| `grafana.enabled` | `true` | the single pane. Keep `grafana.datasources: []`. |
| `tempo.enabled` | `true` | the "T". |
| `alertmanager.enabled` | `true` | alert routing. |
| `otelCollector.enabled` | `true` | OTLP trace ingest gateway. |
| `vector.enabled` | `true` | log shipper DaemonSet (host access). |
| `kubeStateMetrics.enabled` | `true` | cluster object metrics. |
| `nodeExporter.enabled` | `true` | node metrics DaemonSet (host access). |
| `dashboards.enabled` | `true` | bundled dashboard provisioning. |

Each subchart's full value tree passes straight through under its key
(`victoriametrics.*`, `loki.*`, `grafana.*`, `tempo.*`, `alertmanager.*`).

## Security posture

- **Hardened, no operator, no CRDs.** Every image is nonroot (uid 1001 — node-exporter
  runs as 65534), read-only rootfs, all Linux capabilities dropped, 0 fixable CVEs,
  cosign-signed and digest-pinned.
- **Clean components (no host access):** VictoriaMetrics, Loki, Grafana, Tempo,
  Alertmanager, the OTel Collector, kube-state-metrics.
- **Host access by design (toggleable):**
  - **node-exporter** — DaemonSet in the host PID + network namespaces, mounts host
    `/proc`, `/sys`, `/` **read-only**. The Node Exporter Full dashboard needs node
    metrics. `nodeExporter.enabled: false` drops it.
  - **Vector** — DaemonSet mounting host `/var/log` and `/var/lib/docker/containers`
    **read-only** to read pod logs. `vector.enabled: false` drops it.
  These are the deliberate, documented trade-offs for cluster-wide metrics and logs;
  the wider hardened catalog avoids host access.
- **Cluster RBAC** is created for the VictoriaMetrics SA (scrape discovery), Vector SA
  (log metadata enrichment), and kube-state-metrics SA (object listing) — all
  read-only.
- **Fixed-name ConfigMaps** (`lgtm-stack-datasources`, `lgtm-stack-dashboards`,
  `lgtm-stack-vm-scrape`) ⇒ run **one lgtm-stack per namespace**.

## Notes

- This is the heaviest QuenchWorks stack (9 workloads). The bundled
  `ci/default-values.yaml` keeps requests modest (~0.75 vCPU / ~1.1Gi total) to fit a
  single kind node; size up for production.
- VictoriaMetrics single-node is shipped here; the clustered topology (vminsert /
  vmselect / vmstorage) is a tracked follow-up in the component chart.

---

Apache-2.0 · [source](https://github.com/quenchworks/charts) ·
[images](https://github.com/quenchworks/images) · maintained by QuenchWorks.

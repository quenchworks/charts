# observability-stack

A hardened, **operator-free** Kubernetes monitoring bundle: Prometheus, Grafana,
Alertmanager, kube-state-metrics and node-exporter wired together into end-to-end
cluster monitoring, with curated Grafana dashboards provisioned automatically.

It delivers the everyday value of the [kube-prometheus-stack][kps] — metrics,
alerting and the standard Kubernetes dashboards — **without the Prometheus
Operator and its CRDs**. Scrape configuration is plain `kubernetes_sd_configs`
(annotation-based pod discovery plus the kubelet, cAdvisor and the apiserver), so
there are no `ServiceMonitor`/`PrometheusRule` CRDs to install, no admission
webhooks, and no operator pod to keep healthy. Every component image is
QuenchWorks-hardened: built from source on Wolfi, nonroot, 0 fixable CVEs,
cosign-signed with an SBOM and SLSA provenance, and pinned by digest.

| Component | Role | Component chart |
|-----------|------|-----------------|
| **Prometheus** | metrics scraping, storage, alert rules | `quench/prometheus` |
| **Grafana** | 5 curated Kubernetes dashboards; Prometheus pre-wired as the default datasource | `quench/grafana` |
| **Alertmanager** | alert routing + notifications | `quench/alertmanager` |
| **kube-state-metrics** | cluster object metrics (pods, deployments, nodes, …) | templated inline |
| **node-exporter** | per-node host metrics (CPU, memory, disk, filesystem) | templated inline |

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+ (OCI support)

## Usage

The chart is distributed as an OCI artifact:

```sh
oci://ghcr.io/quenchworks/charts/observability-stack
```

### Install

```sh
helm install obs oci://ghcr.io/quenchworks/charts/observability-stack
```

Open Grafana and read the generated admin password:

```sh
kubectl get secret obs-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/obs-grafana 3000:3000
# http://127.0.0.1:3000  (user: admin) — the "Prometheus" datasource is the default
```

The bundled dashboards appear under **Dashboards** immediately; they populate as
soon as Prometheus completes its first scrapes (~30s).

### Uninstall

```sh
helm uninstall obs
```

This removes everything the chart created. **No CRDs are installed, so there is
nothing to clean up afterwards** — unlike operator-based stacks, which leave
`*.monitoring.coreos.com` CRDs behind. PersistentVolumeClaims for Prometheus,
Grafana and Alertmanager are retained by Helm convention; delete them by hand if
you want the data gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=obs
```

### Upgrade

```sh
helm upgrade obs oci://ghcr.io/quenchworks/charts/observability-stack
```

There are no CRDs, so upgrades never require a separate CRD apply step. A major
chart version bump signals a breaking values change; check the release notes.

## How it's wired

The umbrella owns a thin glue layer; everything else passes straight through to
the component charts.

- **Grafana datasource** — the umbrella renders a fixed-name ConfigMap
  (`observability-stack-datasources`) pointing at `http://<release>-prometheus:9090`
  with a fixed datasource uid `prometheus`, and mounts it into Grafana's
  provisioning directory via `grafana.extraVolumes`. `grafana.datasources` stays
  empty. **Fixed names ⇒ run one observability-stack per namespace.**
- **Dashboards** — five dashboard JSON files ship in `dashboards/`, rendered into a
  ConfigMap and provisioned through a Grafana file provider (same mount mechanism
  as the datasource). No Grafana sidecar image required.
- **Prometheus scraping** — `kubernetes_sd_configs` jobs, all release-agnostic (no
  static service names):
  - annotation-based pod scrape (`prometheus.io/scrape: "true"`, honoring
    `prometheus.io/port` and `prometheus.io/path`);
  - the **kubelet** and **cAdvisor**, scraped through the apiserver proxy
    (`/api/v1/nodes/<node>/proxy/metrics[/cadvisor]`);
  - the **apiserver** endpoints.
- **RBAC** — the umbrella creates a ClusterRole + binding for the
  `<release>-prometheus` ServiceAccount granting the read access discovery needs,
  including `nodes/proxy` for the kubelet/cAdvisor scrape. It also projects the SA
  token into the Prometheus pod (the hardened prometheus chart disables automount).
- **kube-state-metrics** — a clean (no host access) Deployment + ClusterRole +
  Service, annotated for discovery.

### Why no operator?

The Prometheus Operator's main jobs are CRD-driven scrape config
(`ServiceMonitor`/`PodMonitor`), CRD-driven alert rules (`PrometheusRule`), and an
admission webhook to validate them. This stack trades those for plain annotation +
`kubernetes_sd` scraping and a Prometheus config you edit directly in values. You
lose CRD-based config and gain a smaller, simpler, hardened footprint with nothing
cluster-scoped to upgrade. If you specifically need `ServiceMonitor` CRDs, this
stack is not for you.

## Dashboards

Five curated Kubernetes dashboards ship in the chart and provision automatically:

| Dashboard | Shows | Needs |
|-----------|-------|-------|
| Node Exporter Full | per-node CPU, memory, disk, network | node-exporter |
| Kubernetes / Compute Resources / Cluster | cluster CPU/memory by namespace + workload | cAdvisor + kube-state-metrics |
| Kubernetes cluster monitoring | pods, deployments, resource pressure | cAdvisor + kube-state-metrics |
| kube-state-metrics v2 | KSM's own health + object counts | kube-state-metrics |
| Prometheus Overview | Prometheus TSDB + scrape health | prometheus |

Choose how many you want — all, some, or none:

```yaml
# All (default): nothing to set.

# Some: keep the ones you want, drop the rest.
dashboards:
  include:
    node-exporter-full: true
    kubernetes-cluster: true
    kubernetes-cluster-monitoring: false
    kube-state-metrics-v2: false
    prometheus-overview: false

# None: Grafana installs with no bundled dashboards.
dashboards:
  enabled: false
```

To add your own, import JSON through the Grafana UI (persisted on the Grafana PVC),
or add files to `dashboards/` and re-release. All bundled dashboards are normalized
to bind their datasource to the provisioned `prometheus` uid.

## Scrape your own workloads

Annotate the workload's **pod template** — the annotation-based job picks it up
with no CRD:

```yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port:   "8080"
        prometheus.io/path:   "/metrics"   # optional, defaults to /metrics
```

To change the scrape config wholesale (extra jobs, relabeling, remote_write), edit
`prometheus.config.prometheusYaml` — it is rendered verbatim into the Prometheus
config.

## Alerting

Alertmanager is installed and Prometheus points at it. Define your routing tree and
receivers through the alertmanager block (see `quench/alertmanager` values), and add
alert rules under `prometheus.config.prometheusYaml` (`rule_files` / inline groups).

## Node and container metrics

`nodeExporter` is **on** by default: cluster observability needs per-node metrics and
the Node Exporter dashboard depends on them. It runs as a host DaemonSet (host
PID/network namespaces, host `/proc` `/sys` `/` mounts) — the deliberate trade-off
for this stack, which the rest of the hardened catalog otherwise avoids. Disable it
with `nodeExporter.enabled: false`.

Container metrics (`container_*`) come from the kubelet's `/metrics/cadvisor`, so
they work with no extra pod. The standalone `cadvisor` DaemonSet is **off** by
default — it is redundant on any cluster whose kubelet serves cAdvisor (nearly all),
and its read-only rootfs cannot mount the ServiceAccount token. Enable it only if
your kubelet does not expose cAdvisor.

## Multiple releases

The fixed-name datasource and dashboard ConfigMaps mean **one observability-stack
per namespace**. To monitor multiple namespaces, install one release per namespace,
or scrape across namespaces from a single release (the pod-discovery job is already
cluster-wide; widen the RBAC binding's scope as needed).

## High availability

Run two Prometheus replicas and spread them across nodes:

```yaml
prometheus:
  replicas: 2
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution: [ ... ]
```

Two replicas give availability but not cross-replica sample deduplication — for
global deduplicated querying, put a Thanos Query (or VictoriaMetrics) layer in front.
The `lgtm-stack` uses VictoriaMetrics as the long-term metrics backend.

## Configuration

See all options with:

```sh
helm show values oci://ghcr.io/quenchworks/charts/observability-stack
```

### Key values

| Value | Default | Notes |
|-------|---------|-------|
| `prometheus.enabled` / `grafana.enabled` / `alertmanager.enabled` | `true` | per-component toggles |
| `prometheus.config.prometheusYaml` | self-scrape + pod/kubelet/cAdvisor/apiserver discovery | the full `prometheus.yml` |
| `prometheus.persistence.size` | `8Gi` | Prometheus TSDB PVC |
| `grafana.auth.adminPassword` | `""` | generated (24 chars) into the grafana Secret when empty |
| `dashboards.enabled` | `true` | provision the bundled dashboards (`false` = none) |
| `dashboards.include.<name>` | all `true` | per-dashboard toggle |
| `kubeStateMetrics.enabled` | `true` | cluster object metrics (no host access) |
| `kubeStateMetrics.digest` | (pinned) | KSM image digest |
| `nodeExporter.enabled` | `true` | per-node host metrics (host DaemonSet) |
| `nodeExporter.digest` | (pinned) | node-exporter image digest |
| `cadvisor.enabled` | `false` | standalone cAdvisor DaemonSet (kubelet already covers it) |

All component-chart values pass through under their block (`prometheus:`,
`grafana:`, `alertmanager:`); see each component chart's `values.yaml` for the full
surface.

## Verify the images

Every bundled component image is cosign-signed (keyless / Sigstore) and pinned by
digest. Verify all five:

```sh
for img in prometheus grafana alertmanager kube-state-metrics node-exporter; do
  cosign verify ghcr.io/quenchworks/images/$img \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/<component> --owner quenchworks`
(same component names as above).

## Security posture

- Operator-free: nothing cluster-scoped beyond the read-only RBAC the scrape jobs need.
- All images built from source on Wolfi, nonroot (uid 1001), 0 fixable CVEs.
- Images cosign-signed with SPDX SBOM + SLSA provenance, pinned by digest.
- node-exporter (and optional cAdvisor) are the only host-privileged pieces, both toggleable.

[kps]: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

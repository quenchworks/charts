# Quenchworks Prometheus Operator

Hardened [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator): runs
Prometheus, Alertmanager and their scrape configuration from Kubernetes custom resources. The
operator and its config-reloader sidecar are built from source, CVE-gated, cosign-signed and
pinned by digest.

## Install

```bash
helm install prom-op oci://ghcr.io/quenchworks/charts/prometheus-operator
```

The ten `monitoring.coreos.com` CRDs ship in `crds/` (Prometheus, PrometheusAgent, Alertmanager,
AlertmanagerConfig, ServiceMonitor, PodMonitor, Probe, ScrapeConfig, PrometheusRule,
ThanosRuler). Helm installs them on the first install only and never upgrades or deletes them:
apply the new `crds/crds.yaml` yourself before moving the chart to a new operator release.

The schemas carry no field descriptions. Upstream's set is 4.6 MB and Helm stores the chart,
`crds/` included, in a release Secret capped at 1 MiB, so the full set cannot install at all.
Types, validation and defaults are upstream's; only `kubectl explain`'s prose is gone.
`qw gen-prometheus-crds` (charts/tools/qw) regenerates the file and the release checks it.

## A Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: main
spec:
  image: ghcr.io/quenchworks/images/prometheus@sha256:<digest>
  serviceAccountName: prometheus    # RBAC to get/list/watch pods, services, endpoints
  serviceMonitorSelector: {}
  serviceMonitorNamespaceSelector: {}
  # The QuenchWorks prometheus image starts through an entrypoint script that passes its own
  # --config.file and storage flags; the operator passes them too, and Prometheus refuses a
  # repeated flag. Run the binary directly:
  containers:
    - name: prometheus
      command: [/usr/bin/prometheus]
```

Every Prometheus and Alertmanager pod gets the config-reloader sidecar from
`configReloader.repository@configReloader.digest`.

## Settings

| Key | Default | |
|---|---|---|
| `watchNamespaces` | `[]` (all) | namespaces whose resources the operator manages |
| `kubeletService.enabled` | `false` | keep a kube-system Service of kubelet endpoints for kubelet/cAdvisor scraping |
| `extraArgs` | `[]` | any other operator flag |
| `service.port` | `8080` | operator metrics at `/metrics` |

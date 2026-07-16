# Quenchworks Harbor observability

A monitoring meta-chart for [Harbor](../harbor). It bundles the Quenchworks
[Prometheus](../prometheus) and [Grafana](../grafana) charts, preconfigured to
scrape a Harbor instance and chart its health. Both sub-charts run nonroot on
minimal, 0-CVE images pinned by digest and cosign-signed (keyless / Sigstore).

This chart monitors Harbor; it does not deploy it. Install the Quenchworks `harbor`
chart with `metrics.enabled=true` in the same namespace (or point the scrape config
at your own Harbor).

## Install

```bash
# install Harbor with metrics on (a separate release), then:
helm install harbor-observability oci://ghcr.io/quenchworks/charts/harbor-observability
```

The bundled Grafana datasource defaults to
`http://harbor-observability-prometheus:9090`. If you install under a different
release name `<rel>`, override `grafana.datasources[0].url` to
`http://<rel>-prometheus:9090`:

```bash
helm install obs oci://ghcr.io/quenchworks/charts/harbor-observability \
  --set grafana.datasources[0].url=http://obs-prometheus:9090
```

## Verify the image

Both bundled images are cosign-signed (keyless / Sigstore):

```bash
for img in prometheus grafana; do
  cosign verify ghcr.io/quenchworks/images/$img \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/prometheus --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/grafana --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `prometheus.enabled` | `true` | Deploy the bundled Prometheus. |
| `grafana.enabled` | `true` | Deploy the bundled Grafana. |
| `dashboards.enabled` | `true` | Provision the Harbor dashboard into Grafana. |
| `dashboards.configMapName` | `harbor-observability-dashboards` | ConfigMap holding the provider + dashboard JSON (referenced by `grafana.extraVolumes`; keep in sync if renamed). |
| `harbor.namespace` | `""` | Namespace of the Harbor release. Empty means this chart's release namespace. |
| `harbor.metricsService` | `harbor-exporter` | harbor-exporter Service name (documentation; mirror in `prometheus.config.prometheusYaml`). |
| `harbor.metricsPort` | `8001` | Exporter metrics port. |
| `harbor.metricsPath` | `/metrics` | Exporter metrics path. |
| `harbor.scrapeInterval` | `30s` | How often Prometheus scrapes Harbor. |
| `harbor.components` | core/registry/jobservice | Per-component `/metrics` targets (documentation). |
| `prometheus.*` | (sub-chart) | All Quenchworks Prometheus values, including `prometheus.config.prometheusYaml`. |
| `grafana.*` | (sub-chart) | All Quenchworks Grafana values (datasources, extraVolumes, etc.). |

The `harbor.*` keys document intent. Because Helm does not template `values.yaml`,
the concrete scrape jobs are spelled out under `prometheus.config.prometheusYaml`;
if you change targets, mirror them there (or override `prometheusYaml` directly).
Everything under `prometheus.*` and `grafana.*` is passed straight through to those
sub-charts, which carry the shared `quench-common` knobs (scheduling, probes,
persistence, security contexts).

## Architecture

Two sub-charts, each behind a `condition` so either can be disabled. Prometheus
runs a single-node TSDB with a self-scrape plus jobs targeting the Harbor metrics
endpoints: the `harbor-exporter` on `:8001/metrics`, and the `core`, `registry`,
and `jobservice` `/metrics` endpoints. Grafana boots with a Prometheus datasource
pointing at the bundled Prometheus Service and a provisioned Harbor dashboard
(component health, request rate, request duration, HTTP status mix, project quota,
task queue, registry request rate, GC/scan task rate).

The dashboard JSON is shipped as a ConfigMap
(`templates/configmap-dashboards.yaml`) and mounted into the Grafana pod through the
grafana sub-chart's `extraVolumes`/`extraVolumeMounts`: a dashboard provider file
plus the JSON. Because Helm does not template `values.yaml`, the ConfigMap name is
fixed (not release-prefixed) so the static sub-chart volume reference stays in sync;
keep `dashboards.configMapName` and the grafana `extraVolumes` entry equal if you
rename it.

Both this chart and Harbor are assumed co-located in the release namespace. When
Harbor lives elsewhere, set `harbor.namespace` and use FQDN targets like
`<harborRelease>-harbor-exporter.<ns>.svc:8001` in `prometheus.config.prometheusYaml`.

## Configuration examples

Reach the UIs over a port-forward:

```bash
# Grafana admin password
kubectl get secret harbor-observability-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Grafana UI (the Harbor dashboard is under the "Harbor" folder)
kubectl port-forward svc/harbor-observability-grafana 3000:3000
# open http://127.0.0.1:3000  (user: admin)

# Prometheus targets
kubectl port-forward svc/harbor-observability-prometheus 9090:9090
# open http://127.0.0.1:9090/targets
```

Point at a Harbor release with a different name. The default scrape targets match a
Quenchworks `harbor` release named `harbor`; for a release named `<harborRelease>`
the exporter Service is `<harborRelease>-harbor-exporter`. Override the scrape jobs:

```yaml
prometheus:
  config:
    prometheusYaml: |
      global:
        scrape_interval: 15s
      scrape_configs:
        - job_name: harbor-exporter
          static_configs:
            - targets: ["myharbor-harbor-exporter:8001"]
```

## Uninstall

```bash
helm uninstall harbor-observability
```

Any PVCs provisioned by the bundled Prometheus/Grafana are retained by Kubernetes.
Delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=harbor-observability
```

## Notes

Depends on the Quenchworks `prometheus` and `grafana` charts, pulled from
`oci://ghcr.io/quenchworks/charts`. Each is behind a `condition`
(`prometheus.enabled` / `grafana.enabled`) so either can be disabled. This chart
monitors Harbor and does not deploy it: run Harbor with `metrics.enabled=true` and
make sure the scrape targets resolve to its Service names.

# Quenchworks Harbor observability

A Harbor-style monitoring meta-chart. It bundles the Quenchworks
[Prometheus](../prometheus) and [Grafana](../grafana) charts, preconfigured to
monitor a [Harbor](../harbor) instance:

- **Prometheus** scrapes the `harbor-exporter` (`:8001/metrics`) plus the
  `core`, `registry`, and `jobservice` `/metrics` endpoints.
- **Grafana** boots with a Prometheus datasource pointing at the bundled
  Prometheus and a provisioned **Harbor** dashboard (component health, request
  rate, request duration, HTTP status mix, project quota, task queue, registry
  request rate, GC/scan task rate).

This chart **monitors** Harbor; it does not deploy it. Install the Quenchworks
`harbor` chart with `metrics.enabled=true` in the same namespace (or point the
scrape config at your own Harbor).

Both sub-charts run nonroot on 0-CVE images pinned by digest.

## Install

```bash
# install Harbor with metrics on (separate release), then:
helm install harbor-observability oci://ghcr.io/quenchworks/charts/harbor-observability
```

> The bundled Grafana datasource defaults to
> `http://harbor-observability-prometheus:9090`. If you install under a different
> release name `<rel>`, override `grafana.datasources[0].url` to
> `http://<rel>-prometheus:9090`.

## Connect

```bash
# Grafana admin password
kubectl get secret harbor-observability-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Grafana UI (Harbor dashboard is under the "Harbor" folder)
kubectl port-forward svc/harbor-observability-grafana 3000:3000
# open http://127.0.0.1:3000  (user: admin)

# Prometheus targets
kubectl port-forward svc/harbor-observability-prometheus 9090:9090
# open http://127.0.0.1:9090/targets
```

## Point at your Harbor

The concrete scrape jobs live in `prometheus.config.prometheusYaml`. The default
targets `harbor-exporter:8001`, `harbor-core:8001`, `harbor-registry:8001`,
`harbor-jobservice:8001` — the Service names of a Quenchworks `harbor` release
named `harbor`. For a release named `<harborRelease>`, the exporter Service is
`<harborRelease>-harbor-exporter`; update the targets (or use FQDNs like
`<harborRelease>-harbor-exporter.<ns>.svc:8001` when Harbor is in another
namespace).

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

## Configuration

| Key | Default | Notes |
|-----|---------|-------|
| `prometheus.enabled` | `true` | Deploy the bundled Prometheus. |
| `grafana.enabled` | `true` | Deploy the bundled Grafana. |
| `dashboards.enabled` | `true` | Provision the Harbor dashboard into Grafana. |
| `dashboards.configMapName` | `harbor-observability-dashboards` | ConfigMap holding the provider + dashboard JSON (referenced by `grafana.extraVolumes`; keep in sync if renamed). |
| `harbor.metricsService` | `harbor-exporter` | harbor-exporter Service name (documentation; mirror in `prometheus.config.prometheusYaml`). |
| `harbor.metricsPort` | `8001` | Exporter metrics port. |
| `prometheus.*` | (sub-chart) | All Quenchworks Prometheus values. |
| `grafana.*` | (sub-chart) | All Quenchworks Grafana values (datasources, extraVolumes, etc.). |

The Grafana dashboard is shipped as a ConfigMap (`templates/configmap-dashboards.yaml`)
and mounted into the Grafana pod through the grafana sub-chart's `extraVolumes` /
`extraVolumeMounts` (a dashboard provider + the JSON). Because Helm does not
template `values.yaml`, the ConfigMap name is fixed (not release-prefixed).

## Verify the images

```bash
for img in prometheus grafana; do
  cosign verify ghcr.io/quenchworks/images/$img \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

## Notes

Depends on the Quenchworks `prometheus` and `grafana` charts, pulled from
`oci://ghcr.io/quenchworks/charts`. Each is behind a `condition`
(`prometheus.enabled` / `grafana.enabled`) so either can be disabled.

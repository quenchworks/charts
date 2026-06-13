# Quenchworks Prometheus

Hardened [Prometheus](https://github.com/prometheus/prometheus) single-node
metrics server / TSDB on a minimal, nonroot, 0-CVE image pinned by digest. The
server is built from source on Wolfi (UI embedded via `builtinassets`) and
exposes the HTTP API + UI on port 9090.

## Install

```bash
helm install prom oci://ghcr.io/quenchworks/charts/prometheus
```

## Configure scrape targets

The full `prometheus.yml` lives in `config.prometheusYaml` and is rendered into a
ConfigMap mounted over `/etc/prometheus/prometheus.yml`. The default config has a
global 15s scrape interval and a self-scrape job (the `up` metric). Override it:

```yaml
config:
  prometheusYaml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]
      - job_name: node-exporter
        static_configs:
          - targets: ["node-exporter:9100"]
  retentionTime: "30d"
  extraArgs:
    - --storage.tsdb.retention.size=10GB
```

`helm upgrade` rolls the pod on the config checksum. For a live reload without a
restart (`--web.enable-lifecycle` is on by default):

```bash
curl -XPOST http://prom-prometheus:9090/-/reload
```

## Query

```bash
# instant query
curl 'http://prom-prometheus:9090/api/v1/query?query=up'
# range query
curl 'http://prom-prometheus:9090/api/v1/query_range?query=up&start=-5m&end=now&step=30s'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/prometheus \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/prometheus` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node. |
| `config.prometheusYaml` | self-scrape | The full `prometheus.yml`, mounted from a ConfigMap. |
| `config.retentionTime` | `"15d"` | `--storage.tsdb.retention.time` (Prometheus duration). |
| `config.extraArgs` | `[]` | Raw flags appended to the server (e.g. retention.size). |
| `persistence.enabled` | `true` | 16Gi PVC mounted at `/prometheus` (TSDB). |
| `service.port` | `9090` | HTTP API + UI + lifecycle endpoints. |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The TSDB lives on the writable `/prometheus` PVC; `/tmp` is a writable
emptyDir. Prometheus has **no built-in authentication** — there is no Secret to
manage. The NetworkPolicy is the trust boundary; keep it enabled, and front the
service with an authenticating proxy if you must expose it beyond the cluster.

## Notes

Single node. Prometheus' HA story (two identical replicas) and remote-write to a
long-term store (VictoriaMetrics) are tracked follow-ups. Pairs with the
Quenchworks exporters as scrape targets and Grafana for dashboards. Depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

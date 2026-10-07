# Quenchworks search-stack

Search with a UI in one install:

- [OpenSearch](https://opensearch.org) indexes and searches documents, logs and metrics.
  The default is an HA cluster (3 cluster-manager and 2 data nodes); `opensearch.mode:
  single` runs one node.
- [OpenSearch Dashboards](https://opensearch.org/docs/latest/dashboards/) is the UI:
  Discover, dashboards, visualizations, Dev Tools, alerting and anomaly detection. The
  stack points it at its own OpenSearch.

Every image is minimal, nonroot, 0-CVE, cosign-signed and pinned by digest. Both ship
without the security plugin, so there is no login: both subcharts' NetworkPolicies limit
access to the release namespace. Put an authenticating proxy in front of Dashboards before
exposing it.

## Install

```bash
helm install search oci://ghcr.io/quenchworks/charts/search-stack -n search --create-namespace
kubectl -n search port-forward svc/search-opensearch-dashboards 5601:5601   # http://127.0.0.1:5601
```

One node, for a laptop or a test cluster:

```bash
helm install search oci://ghcr.io/quenchworks/charts/search-stack -n search --create-namespace \
  --set opensearch.mode=single
```

## Configuration

Values under `opensearch` and `opensearch-dashboards` pass straight through to the
[opensearch](../opensearch) and [opensearch-dashboards](../opensearch-dashboards) charts.

| Key | Default | Meaning |
|---|---|---|
| `opensearch.mode` | `ha` | `ha` or `single` |
| `opensearch-dashboards.enabled` | `true` | Install the UI |
| `opensearch-dashboards.opensearch.hosts` | this release's OpenSearch | Rendered with tpl |
| `opensearch-dashboards.extraConfig` | `{}` | Merged into `opensearch_dashboards.yml` |
| `ingress.enabled` | `false` | Ingress to Dashboards (or `ingress.serviceName`) |

Dashboards and OpenSearch share `appVersion` 3.8.0; keep them on the same minor.

# OpenCost

[OpenCost](https://www.opencost.io) is the CNCF cost monitoring model for Kubernetes. It
allocates cluster cost by namespace, workload, label and more, and serves the result
over an HTTP API. This chart runs the cost model on the QuenchWorks image: built from
source, nonroot (uid 1001), 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install opencost oci://ghcr.io/quenchworks/charts/opencost
kubectl port-forward svc/opencost 9003:9003
curl 'http://127.0.0.1:9003/allocation/compute?window=1d'
```

## Metrics backend

With `prometheus.endpoint` empty (the default), OpenCost uses its built-in collector
data source, so the chart works on its own. For history across restarts, or across
Prometheus shards, point it at a query endpoint:

```yaml
prometheus:
  endpoint: http://prometheus-server.monitoring:9090   # or a Thanos / Mimir query frontend
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `image.digest` | pinned | the signed QuenchWorks image |
| `clusterId` | `default-cluster` | `CLUSTER_ID` in the cost data |
| `prometheus.endpoint` | `""` | `PROMETHEUS_SERVER_ENDPOINT`; empty uses the collector data source |
| `cloudProvider` | `""` | `CLOUD_PROVIDER` override; empty auto-detects |
| `productAnalytics` | `false` | OpenCost's anonymous usage reporting |
| `rbac.create` | `true` | cluster-wide read-only role for the objects OpenCost prices |
| `service.port` | `9003` | API port |
| `networkPolicy.enabled` | `true` | ingress only to the API port |

The pod runs with a read-only root filesystem and all capabilities dropped; `/tmp` is
an emptyDir. The ClusterRole grants `get`, `list` and `watch` only; OpenCost writes
nothing to the Kubernetes API.

The chart depends on the `quench-common` library chart from
`oci://ghcr.io/quenchworks/charts`.

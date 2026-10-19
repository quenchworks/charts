# Quenchworks cost-stack

Kubernetes cost monitoring in one install: [OpenCost](https://github.com/opencost/opencost)
prices every pod, namespace and node from metrics in a bundled Prometheus, and Grafana comes
with that Prometheus already provisioned as its datasource. No operator and no CRDs; every
pod runs nonroot on a read-only root filesystem, and every image is 0-CVE, cosign-signed and
pinned by digest.

```
kubelet cAdvisor (container usage) ---\
OpenCost /metrics (prices, requests) ---> <release>-prometheus:9090
OpenCost --(PromQL)--> <release>-prometheus --> /allocation on <release>-opencost:9003
Grafana --(Prometheus datasource)--> <release>-prometheus
```

OpenCost emits the pod, node and request metrics it needs, so no kube-state-metrics or
node-exporter is bundled. Prometheus gets a ClusterRole to discover pods and nodes and to
read the kubelet's cAdvisor through the API server.

## Install

```bash
helm install cost oci://ghcr.io/quenchworks/charts/cost-stack
kubectl port-forward svc/cost-opencost 9003:9003
curl -s 'http://127.0.0.1:9003/allocation/compute?window=1d&aggregate=namespace'
```

Allocation fills in after Prometheus has a few scrapes (a minute or two). Grafana:

```bash
kubectl get secret cost-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/cost-grafana 3000:3000
```

## Values

| Key | Default | Notes |
|---|---|---|
| `opencost.enabled` | `true` | Any opencost chart value under `opencost.` passes through. |
| `opencost.clusterId` | `default-cluster` | Cluster name in the cost data. |
| `opencost.cloudProvider` | detected | Set `aws`, `azure`, `gcp`, ... to override. |
| `prometheus.enabled` | `true` | Any prometheus chart value under `prometheus.` passes through. |
| `prometheus.persistence.size` | `8Gi` | TSDB volume. |
| `prometheus.config.prometheusYaml` | 3 jobs | Self, annotated pods (OpenCost), kubelet cAdvisor. Keep the last two. |
| `grafana.enabled` | `true` | Any grafana chart value under `grafana.` passes through. |
| `grafana.auth.adminPassword` | generated | Kept in `<release>-grafana`. |
| `ingress.enabled` | `false` | Fronts Grafana unless `ingress.serviceName` says otherwise. |

The wiring ConfigMaps have fixed names, so run one cost-stack per namespace. Keep
`grafana.datasources` empty; the stack provides the Prometheus datasource itself. To use a
Prometheus you already run, set `prometheus.enabled=false`, `opencost.prometheus.endpoint` to
its URL and `opencost.extraEnvVarsCM=""`; that Prometheus must scrape cAdvisor and OpenCost.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/opencost \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

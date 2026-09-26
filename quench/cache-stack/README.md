# cache-stack

A cache with metrics in one install:
- [Valkey](https://valkey.io), the Redis-compatible cache, with a redis_exporter sidecar
- Prometheus, which discovers the exporter in the release namespace
- Grafana, with the Prometheus datasource and the
  [redis_exporter dashboard](https://github.com/oliver006/redis_exporter/tree/master/contrib)
  provisioned

Every component is a QuenchWorks chart on a hardened, nonroot, 0-CVE image, pinned by
digest and cosign-signed.

## Install

```sh
helm install cache oci://ghcr.io/quenchworks/charts/cache-stack
kubectl get secret cache-valkey -o jsonpath='{.data.valkey-password}' | base64 -d
```

Point Redis clients at `cache-valkey:6379` with that password. For Grafana:

```sh
kubectl port-forward svc/cache-grafana 3000:3000
kubectl get secret cache-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

The dashboard is "Redis Dashboard for Prometheus Redis Exporter 1.x".

## How the pieces connect

- The valkey subchart runs redis_exporter beside Valkey, behind the
  `<release>-valkey-metrics` Service on port `metrics` (9121).
- Prometheus finds it with `kubernetes_sd_configs` (role `endpoints`,
  `own_namespace: true`). It keeps Services labelled `app.kubernetes.io/name=valkey`
  that have a port named `metrics`, and labels each series with its `namespace`,
  which the dashboard filters on.
- The stack grants Prometheus's ServiceAccount a namespaced Role (read services,
  endpoints, endpointslices and pods) and projects its token, which the prometheus
  chart does not mount by default.
- Grafana's datasource (uid `prometheus`) and dashboard come from ConfigMaps this
  chart owns.

Any other Valkey installed in the same namespace with the quench valkey chart and
`metrics.enabled=true` is discovered too.

## Values

Each component takes its own chart's values under its key: `valkey.*`,
`prometheus.*`, `grafana.*`. The stack's own keys:

| Key | Default | Meaning |
|---|---|---|
| `valkey.enabled` / `prometheus.enabled` / `grafana.enabled` | `true` | turn a component off |
| `valkey.metrics.enabled` | `true` | the exporter sidecar the stack scrapes |
| `dashboards.enabled` | `true` | provision the redis_exporter dashboard |

One cache-stack per namespace: the Grafana provisioning ConfigMaps have fixed names.

## Release gate

On kind, the gate writes keys into Valkey through its password. It then requires three
things: Prometheus reports `redis_up == 1` for the discovered exporter with the right
`namespace` label, the key count reaches Prometheus, and Grafana finds the provisioned
dashboard and answers a query through its Prometheus datasource.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Quenchworks linkerd-viz

[Linkerd Viz](https://linkerd.io/2/reference/cli/viz/) on QuenchWorks images built from source,
0-CVE, cosign-signed and pinned by digest: `linkerd viz stat`, `top`, `routes`, `edges` and `tap`
against your own Prometheus.

Tracks Linkerd's EDGE releases (this is edge-26.8.4), like the QuenchWorks linkerd chart it runs on.

| Component | Deployment | What it does |
|---|---|---|
| metrics-api | `metrics-api` | answers the CLI's stats queries from Prometheus |
| tap | `tap` | serves the `tap.linkerd.io` API (APIService `v1alpha1.tap.linkerd.io`) and streams live requests from proxies |
| tap injector (webhook) | `tap-injector` | turns on each injected proxy's tap server for tap's mesh identity |
| namespace-metadata (post-install Job) | | labels this namespace `linkerd.io/extension=viz` so the CLI finds it |

Every viz pod is meshed by the linkerd chart's proxy injector. Object names are upstream's fixed
names because the CLI looks them up by name, so install one release per cluster, in `linkerd-viz`.

## Not included: the web dashboard

The `web` dashboard is not part of this chart. Its bundled JavaScript carries known CVEs
(decode-uri-component 0.2.2, linkify-it 2.2.0, path-to-regexp 1.8.0, moment 2.29.4) that sit inside
a minified bundle where an image scan cannot see them, so a 0-CVE scan of that image would be
false. Use the CLI, or Grafana on the same Prometheus.

Also not included: a bundled Prometheus (see below), Jaeger integration, ServiceProfile defaults
for the control plane, and the PodSecurityPolicy objects.

## Install

The QuenchWorks `linkerd-crds`, `linkerd-cni` and `linkerd` charts must already run (see the
linkerd chart's README). Then:

```bash
helm install linkerd-viz oci://ghcr.io/quenchworks/charts/linkerd-viz \
  -n linkerd-viz --create-namespace \
  --set prometheusUrl=http://prometheus.monitoring.svc.cluster.local:9090
```

Pods meshed before this install have no tap until they are restarted
(`kubectl -n <ns> rollout restart deploy`). Then, with the linkerd CLI edge-26.8.4:

```bash
linkerd viz stat deploy -n <ns>
linkerd viz tap deploy/<name> -n <ns>
```

`linkerd viz tap` needs the ClusterRole `linkerd-linkerd-viz-tap-admin` (or cluster-admin) bound to
the user running it.

## Prometheus

`prometheusUrl` is required. That Prometheus must scrape every meshed pod's proxy admin port
(container `linkerd-proxy`, port `linkerd-admin`, 4191, `/metrics`) and keep the labels
metrics-api queries by. A scrape job that does (the release gate runs it on the QuenchWorks
`prometheus` chart, with a ClusterRole to list pods):

```yaml
- job_name: linkerd-proxy
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_phase]
      regex: Pending|Running
      action: keep
    - source_labels: [__meta_kubernetes_pod_container_name, __meta_kubernetes_pod_container_port_name]
      regex: linkerd-proxy;linkerd-admin
      action: keep
    - source_labels: [__meta_kubernetes_namespace]
      target_label: namespace
    - source_labels: [__meta_kubernetes_pod_name]
      target_label: pod
    - action: labelmap
      regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
    - action: labelmap
      regex: __meta_kubernetes_pod_label_linkerd_io_(.+)
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `prometheusUrl` | required | your Prometheus |
| `prometheusCredsSecret` | `""` | Secret with `user` and `password` for Prometheus basic auth |
| `linkerdNamespace` | `linkerd` | namespace of the linkerd chart's release |
| `identityTrustDomain` | `cluster.local` | must match the linkerd chart's `identity.trustDomain` |
| `tapInjector.failurePolicy` | `Ignore` | `Fail` blocks pod creation while the tap injector is down |
| `logLevel` | `info` | all viz components |

## Release gate

The gate installs linkerd-crds, linkerd-cni and linkerd into kind and runs the linkerd mesh gate,
then the QuenchWorks prometheus chart with the scrape job above, then this chart. It requires every
viz pod meshed on a QuenchWorks image, the namespace labelled by the namespace-metadata Job,
`linkerd viz stat deploy` showing a non-zero success rate for an injected server under load from an
injected client, and `linkerd viz tap` streaming at least one request.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

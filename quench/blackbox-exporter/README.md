# Quenchworks Blackbox Exporter

Hardened [Prometheus Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
on a minimal, nonroot, 0-CVE image built from source, cosign-signed and pinned by
digest. It probes endpoints over HTTP, HTTPS, DNS, TCP, ICMP and gRPC and exposes the
result as Prometheus metrics for scraping.

## Install

```sh
helm install blackbox-exporter oci://ghcr.io/quenchworks/charts/blackbox-exporter
```

The chart is bootable with no configuration: when `config.yaml` is empty the container
uses the `blackbox.yml` the image ships, which defines a single `http_2xx` module.

## Probing

The exporter does not probe on a schedule. Prometheus calls `/probe` with the real
target in a query parameter:

```sh
kubectl port-forward svc/blackbox-exporter 9115:9115
curl 'http://127.0.0.1:9115/probe?target=https://example.com&module=http_2xx'
```

The response is Prometheus text; `probe_success 1` means the probe passed.
`/metrics` exposes the exporter's own metrics (not probe results), and `/-/healthy`
answers 200 once the configuration has parsed.

A Prometheus scrape config uses the standard relabel pattern: scrape this Service,
carry the target through `__param_target`, and rewrite `__address__` back to the
exporter.

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` / `image.digest` | pinned | Image, always pinned by digest. |
| `replicaCount` | `1` | The exporter is stateless, so it scales horizontally. |
| `containerPort` | `9115` | Port the exporter listens on. |
| `config.yaml` | `""` | Full modules document. Empty means the image's built-in `http_2xx` module. |
| `config.existingConfigMap` | `""` | Use an externally-managed ConfigMap (key `blackbox.yml`) instead. |
| `extraArgs` | `[]` | Extra flags appended to the command. |
| `service.type` / `service.port` | `ClusterIP` / `9115` | Service exposure. |
| `autoscaling.*` | disabled | Optional HPA on CPU. |
| `ingress.*` | disabled | Optional HTTP Ingress. |
| `networkPolicy.*` | enabled, external allowed | Prometheus often scrapes from another namespace. |
| `podDisruptionBudget.*` | enabled, `minAvailable: 1` | |

Standard quench-common knobs (`nodeSelector`, `affinity`, `tolerations`,
`extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides, security contexts) are
supported as in every Quenchworks chart.

Defining `config.yaml` REPLACES the built-in configuration rather than merging with
it, so include an `http_2xx` module yourself if you still want one.

## Security

Runs as uid 1001 with a read-only root filesystem and all capabilities dropped. ICMP
probing needs `CAP_NET_RAW`, which this chart does not grant by default; add it through
`containerSecurityContext` if you need `prober: icmp`.

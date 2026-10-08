# prometheus-nats-exporter

[prometheus-nats-exporter](https://github.com/nats-io/prometheus-nats-exporter) as a standalone
Deployment: it reads one NATS server's HTTP monitoring endpoint (`/varz`, `/connz`, `/routez`,
`/subz`, `/healthz`, optionally JetStream `/jsz`) and serves it as Prometheus metrics on port 7777.
Runs on the QuenchWorks prometheus-nats-exporter image (built from source on Wolfi, nonroot,
0 fixable CVEs, cosign-signed, pinned by digest).

## Install

Point it at the server's monitoring port (8222 by default; the QuenchWorks nats chart serves it on
its headless Service):

```sh
helm install nats-exporter oci://ghcr.io/quenchworks/charts/prometheus-nats-exporter \
  --set target.url=http://my-nats-headless:8222
kubectl port-forward svc/nats-exporter-prometheus-nats-exporter 7777 & curl -s localhost:7777/metrics | grep '^gnatsd_varz_'
```

`gnatsd_varz_*` series labelled `server_id` mean the exporter reached the server. The exporter
serves only `/metrics`, and each scrape queries NATS, so the probes are TCP checks.

One exporter watches one server: for a cluster, install one release per server, each pointed at
that server's pod address.

## Values

| Key | Default | Meaning |
|---|---|---|
| `target.url` | required | the NATS monitoring endpoint, `http://host:8222` |
| `collectors` | `[varz, connz, routez, subz, healthz]` | monitoring endpoints to export (exporter flags) |
| `jetstream` | `""` | `all`, `streams`, `consumers` or `accounts` to add JetStream metrics |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `extraArgs` | `[]` | other exporter flags (`-prefix`, `-use_internal_server_id`, ...) |

## Release gate

The gate installs this repository's nats chart in kind, points the exporter at its monitoring port,
and passes only when `/metrics` reports a `gnatsd_varz_*` (or `nats_varz_*`) series labelled with a
`server_id`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

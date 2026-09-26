# Fluentd

[Fluentd](https://www.fluentd.org) collects, parses, buffers and routes logs. This chart
runs it as an aggregator: log shippers (Fluent Bit, Vector, fluent-logger libraries) send
to it over the forward protocol or HTTP, and your pipeline routes the events on. It runs
on the QuenchWorks fluentd image: Fluentd 1.19 on Wolfi Ruby 4.0, nonroot, read-only root
filesystem, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install logs oci://ghcr.io/quenchworks/charts/fluentd
```

The default pipeline accepts forward (24224) and HTTP (9880) and prints every event to
stdout. Replace it with the `config` value (fluent.conf syntax), and keep `ports` in step
with its sources.

## Plugins

The image carries Fluentd's built-in plugins (forward, http, tail, file, stdout, ...).
Add others by building a derived image:

```Dockerfile
FROM ghcr.io/quenchworks/images/fluentd:1.19.3
RUN ["/usr/bin/ruby", "/usr/bin/gem", "install", "--no-document", "fluent-plugin-s3"]
```

`GEM_HOME` is preset, so gems land beside Fluentd's own. The derived image needs a build
stage with write access; the runtime image is nonroot and has no shell.

## Values

| Key | Default | Meaning |
|---|---|---|
| `config` | forward + http to stdout | the pipeline, as fluent.conf text |
| `ports` | forward 24224, http 9880 | container and Service ports for your sources |
| `replicas` | `1` | aggregator replicas (each with its own buffer PVC) |
| `persistence.*` | `8Gi` PVC | `/fluentd/buffer`, for file buffers that survive restarts |
| `extraArgs` / `extraEnv` | `[]` | extra fluentd flags / env |

This chart does not run Fluentd as a node log collector (a DaemonSet reading
`/var/log/pods` needs root); use the logging-stack chart's Vector for that.

The release gate installs the chart on kind, sends one event to the HTTP input through a
port-forward and one over the forward protocol with `fluent-cat` from another pod, and
requires both in the aggregator's output.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

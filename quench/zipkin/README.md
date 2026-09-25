# Zipkin

[Zipkin](https://zipkin.io) is a distributed tracing server: it collects spans from
instrumented services, stores them, and serves the query API and the Lens UI. This chart
runs it on the QuenchWorks zipkin image. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install zipkin oci://ghcr.io/quenchworks/charts/zipkin
kubectl port-forward svc/zipkin 9411:9411
# open http://127.0.0.1:9411/zipkin/
```

Send spans to `http://zipkin.<namespace>.svc:9411/api/v2/spans` (JSON or proto3), or
point an OpenTelemetry Collector's zipkin exporter there.

## Storage

| `storage.type` | Values |
|---|---|
| `mem` (default) | none; spans live in the pod and go away on restart |
| `elasticsearch` | `storage.elasticsearch.hosts` (Elasticsearch or OpenSearch) |
| `cassandra3` | `storage.cassandra.contactPoints`, `keyspace` |
| `mysql` | `storage.mysql.host/port/database/user` |

`storage.existingSecret` + `existingSecretPasswordKey` supplies the backend password.
Other Zipkin settings go in `env`, for example `COLLECTOR_SAMPLE_RATE`,
`KAFKA_BOOTSTRAP_SERVERS` or `RABBIT_ADDRESSES`.

## What the image leaves out

The QuenchWorks image removes the Pulsar and Scribe collectors: their fixed dependencies
cannot be swapped into the release jar. HTTP, gRPC, Kafka, RabbitMQ and ActiveMQ
collection and every storage backend are included.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `1` | keep 1 with `mem`; scale freely with a real backend |
| `storage.type` | `mem` | span storage |
| `javaOpts` | `-XX:MaxRAMPercentage=75` | JVM flags (JAVA_TOOL_OPTIONS) |
| `env` | `{}` | other Zipkin settings |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind, posts a span over the v2 API, and requires
Zipkin to list its service, return the trace by ID, report its version and serve the UI.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

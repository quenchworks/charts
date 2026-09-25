# Karapace

[Karapace](https://karapace.io) is Aiven's schema registry (Avro, JSON Schema,
Protobuf) and REST proxy for Apache Kafka, both compatible with the Confluent APIs.
This chart runs the registry, and optionally the REST proxy, on the QuenchWorks
karapace image. The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by
digest.

## Install

```sh
helm install karapace oci://ghcr.io/quenchworks/charts/karapace \
  --set kafka.bootstrapServers=kafka.data.svc:9092 \
  --set restProxy.enabled=true
```

Point clients at `http://karapace-registry.<namespace>.svc:8081` (the Confluent
serializers' `schema.registry.url`) and the proxy at `:8082`.

## Settings

The chart sets the connection settings; everything else is a Karapace setting passed
as `KARAPACE_<NAME>` through `config`, and secrets through `existingSecret` (a Secret
whose keys are full `KARAPACE_*` names):

```yaml
config:
  SECURITY_PROTOCOL: SASL_SSL
  SASL_MECHANISM: SCRAM-SHA-512
  SASL_PLAIN_USERNAME: karapace
existingSecret: karapace-kafka   # KARAPACE_SASL_PLAIN_PASSWORD: ...
```

`registry.replicationFactor` is the schemas topic's replication factor: 1 fits a
single broker, raise it to 3 on a production cluster. Registry replicas elect a primary
through the Kafka consumer group and forward writes to it by pod IP.

Neither service authenticates by default; keep them internal or configure Karapace's
`registry_authfile` / `rest_authorization`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `kafka.bootstrapServers` | `""` | Kafka bootstrap servers (required) |
| `registry.replicas` | `1` | registry pods |
| `registry.replicationFactor` | `1` | schemas topic replication |
| `registry.compatibility` | `BACKWARD` | default compatibility level |
| `restProxy.enabled` | `false` | run the REST proxy |
| `config` | `{}` | other `KARAPACE_*` settings |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the QuenchWorks kafka chart as a one-broker cluster, then this
chart with the REST proxy, registers an Avro schema, reads it back, and requires the
proxy to list the schemas topic.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# streaming-stack

An event-streaming platform in one install:
- **Kafka 4.3** in KRaft mode: 3 combined broker/controller nodes, no ZooKeeper.
- **Karapace**: the schema registry (Confluent Schema Registry API) and the Kafka REST
  proxy.
- **AKHQ**: a web console for topics, consumer groups, messages and schemas.

Every component is a QuenchWorks chart and image: hardened, nonroot, 0-CVE, pinned by
digest and cosign-signed.

## Install

```sh
helm install streaming oci://ghcr.io/quenchworks/charts/streaming-stack
kubectl port-forward svc/streaming-akhq 8080:8080   # then http://127.0.0.1:8080
```

| Service | Address | Use |
|---|---|---|
| Kafka | `streaming-kafka:9092` | producers and consumers |
| Schema registry | `http://streaming-karapace-registry:8081` | Avro, JSON Schema and Protobuf schemas |
| REST proxy | `http://streaming-karapace-rest-proxy:8082` | produce and consume over HTTP |
| AKHQ | `http://streaming-akhq:8080` | the console |

## How the pieces connect

- **Fixed names.** Each subchart takes the others' addresses as plain values, so every
  object is named `streaming-*` and the schema pins those names. Install one stack per
  namespace.
- **Schemas** live in Kafka's `_schemas` topic, replicated 3 ways to match the cluster
  (`karapace.registry.replicationFactor`).
- **AKHQ** has one connection, `streaming`, with the Kafka bootstrap and the schema
  registry, so it shows topics, messages and schemas together.
- **Network.** The Kafka chart's NetworkPolicy admits clients from the release
  namespace. Clients elsewhere need `kafka.networkPolicy.allowExternal`.

## Security

Kafka runs PLAINTEXT on 9092 and AKHQ has no login by default. Before exposing them,
configure Kafka authentication through the kafka chart's values and AKHQ security under
`akhq.akhqConfig.security` (or put AKHQ behind oauth2-proxy).

## Values

Each component takes its own chart's values under its key: `kafka.*`, `karapace.*`,
`akhq.*`. The stack's own choices:

| Key | Default | Meaning |
|---|---|---|
| `kafka.replicaCount` | `3` | KRaft nodes |
| `karapace.enabled` | `true` | schema registry and REST proxy |
| `karapace.restProxy.enabled` | `true` | the REST proxy |
| `karapace.registry.replicationFactor` | `3` | `_schemas` topic replication |
| `akhq.enabled` | `true` | the console |

## Release gate

On kind, with a one-node Kafka, the gate:
1. registers an Avro schema in Karapace;
2. produces a record through the REST proxy and reads it back with a Kafka consumer;
3. requires AKHQ healthy and listing both the topic and the schema subject.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

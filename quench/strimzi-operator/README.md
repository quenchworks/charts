# QuenchWorks Strimzi Operator

[Strimzi](https://strimzi.io) runs Apache Kafka on Kubernetes from custom
resources: `Kafka`, `KafkaNodePool`, `KafkaTopic`, `KafkaUser`,
`KafkaConnect`, `KafkaConnector` and `KafkaMirrorMaker2`. This chart installs
the Strimzi 1.2.0 cluster operator and its CRDs (in `crds/`). The operator
image is nonroot, 0 fixable CVEs, pinned by digest and cosign-signed. The
brokers, controllers, Connect, MirrorMaker 2 and Kafka Exporter it creates run
on the QuenchWorks `strimzi-kafka` image (Kafka 4.3.1); the topic operator,
user operator and kafka-init run on the operator image.

## Install

```bash
helm install strimzi oci://ghcr.io/quenchworks/charts/strimzi-operator \
  -n kafka --create-namespace
```

Then create a single-node KRaft cluster in the same namespace:

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: dual-role
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 1
  roles: [controller, broker]
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 10Gi
        kraftMetadata: shared
---
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    listeners:
      - { name: plain, port: 9092, type: internal, tls: false }
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

## Values

| Key | Default | Notes |
|---|---|---|
| `kafkaImage` | QuenchWorks strimzi-kafka 1.2.0-kafka-4.3.1 | brokers, controllers, Connect, MirrorMaker 2, Kafka Exporter |
| `watchAnyNamespace` | `false` | `false` watches the release namespace only |
| `replicaCount` | `1` | leader election is always on |
| `logLevel` | `INFO` | operator log level |
| `upstreamImages.*` | upstream quay.io images | bridge, kaniko, buildah, maven builder (not built by QuenchWorks) |

## Notes

- **Kafka 4.3.1 only.** Strimzi 1.2.0 refuses to start unless every Kafka
  version it supports (4.2.0 to 4.3.1) maps to an image, so all of them map to
  the one 4.3.1 image. Leave `spec.kafka.version` unset or set it to `4.3.1`.
- **Cruise Control is not supported.** The `strimzi-kafka` image leaves Cruise
  Control out: every Cruise Control release runs Jetty 9.4, which has CVEs with
  no 9.4 fix. Do not set `spec.cruiseControl` on a `Kafka`, and do not use
  `KafkaRebalance` or auto-rebalancing; they will fail. The CRDs still ship
  because the operator watches them.
- **Images QuenchWorks does not build:** Kafka Bridge, and kaniko, buildah and
  the maven builder (used only by `KafkaConnect` `spec.build`). They default to
  upstream's quay.io images and are pulled only for those resources.
- **One release per cluster.** The operator binds the pods it creates to the
  ClusterRoles `strimzi-kafka-broker`, `strimzi-entity-operator` and
  `strimzi-kafka-client` by name, so the chart creates them with those names.
- Helm installs CRDs from `crds/` but never upgrades them. Apply the new
  `crds/crds.yaml` by hand when you upgrade the chart.

# Quenchworks kafka-exporter

Hardened [kafka_exporter](https://github.com/danielqsj/kafka_exporter) on a
minimal, nonroot, 0-CVE image, built from source and pinned by digest.

It exports Kafka brokers, topics, partition offsets and consumer-group lag as
Prometheus metrics on port 9308.

## Install

```sh
helm install kafka-exporter oci://ghcr.io/quenchworks/charts/kafka-exporter \
  --set 'kafkaServers[0]=my-kafka:9092'
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/kafka-exporter \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/kafka-exporter --owner quenchworks`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `kafkaServers` | `[kafka:9092]` | Bootstrap brokers. |
| `sasl.enabled`, `sasl.mechanism`, `sasl.username` | off, `plain` | SASL; also `scram-sha256`, `scram-sha512`. |
| `sasl.existingSecret`, `sasl.existingSecretPasswordKey` | `""`, `password` | Secret holding the SASL password. |
| `tls.enabled`, `tls.existingSecret` | off | TLS to the brokers; the Secret holds `ca.crt` (and `tls.crt`/`tls.key` for mTLS). |
| `topicFilter`, `groupFilter` | all | Regexes for the topics and consumer groups to collect. |
| `kafkaVersion` | exporter default | Broker protocol version the client speaks. |
| `extraArgs` | `[]` | Appended to the command line. |

Key metrics: `kafka_brokers`, `kafka_topic_partitions`,
`kafka_topic_partition_current_offset`, `kafka_consumergroup_lag`.

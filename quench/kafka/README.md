# Quenchworks Kafka

Hardened Apache Kafka on a minimal, nonroot, 0-CVE image pinned by digest. Runs in
KRaft mode (no Zookeeper) as a single combined controller + broker node. The image
builds `server.properties` from environment at boot and formats KRaft storage; the
chart pins the image by its signed digest.

## Install

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka
```

Tune the broker:

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka \
  --set kraft.numPartitions=3 --set kraft.autoCreateTopics=false
```

Pass any other Kafka property without changing the chart, via `extraEnvVars`
(the image maps `KAFKA_*` env vars into `server.properties`):

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka \
  --set 'extraEnvVars[0].name=KAFKA_LOG_RETENTION_HOURS' \
  --set 'extraEnvVars[0].value=24'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kafka \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/kafka \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/kafka` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `kraft.nodeId` | `1` | KRaft node id. |
| `kraft.autoCreateTopics` | `true` | Auto-create topics on first produce. |
| `kraft.numPartitions` | `1` | Default partitions per topic. |
| `kraft.offsetsTopicReplicationFactor` | `1` | Single node, so internal topics replicate once. |
| `kraft.transactionStateLogReplicationFactor` | `1` | |
| `kraft.transactionStateLogMinIsr` | `1` | |
| `kraft.clusterId` | `""` | Fixed cluster id, or generated + persisted if empty. |
| `kraft.heapOpts` | `-Xmx1G -Xms1G` | JVM heap. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/kafka`. |
| `service.port` | `9092` | PLAINTEXT client listener. |
| `extraEnvVars` | `[]` | Inject any `KAFKA_*` property. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`, scheduling
(`affinity`/`nodeSelector`/`tolerations`/`topologySpreadConstraints`), `initContainers`,
`sidecars`, `extraVolumes`/`extraVolumeMounts`, `lifecycleHooks`, configurable probes,
and overridable security contexts.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/kafka` and `/tmp` are writable.

## Notes

Single-node KRaft, PLAINTEXT, reachable only inside the cluster (the NetworkPolicy
restricts ingress to the release namespace). Multi-node clustering, SASL/TLS auth, a
metrics exporter, and topic provisioning are tracked follow-ups; they need
corresponding support in the image entrypoint. Depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Kafka

Hardened Apache Kafka on a minimal, nonroot, 0-CVE image pinned by digest. Runs in
KRaft mode (no Zookeeper) as a highly available multi-broker cluster: three brokers by
default, each a combined KRaft controller + broker, forming a controller quorum with
replicated partitions. The image builds `server.properties` from environment at boot
and formats KRaft storage; the chart pins the image by its signed digest.

## Install

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka
```

This brings up a 3-broker HA cluster. Each broker derives its `node.id` from its
StatefulSet ordinal, advertises its own stable headless-Service DNS name, and joins the
KRaft controller quorum listed in `controller.quorum.voters`. A shared cluster id is
generated on first install and kept in a Secret so upgrades reuse it.

Tune the cluster:

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka \
  --set replicaCount=5 --set kraft.numPartitions=6
```

Pass any other Kafka property the entrypoint maps, via `extraEnvVars`:

```bash
helm install my-kafka oci://ghcr.io/quenchworks/charts/kafka \
  --set 'extraEnvVars[0].name=KAFKA_LOG_RETENTION_HOURS' \
  --set 'extraEnvVars[0].value=24'
```

## High availability

- **Topology**: a StatefulSet of `replicaCount` brokers (default 3), each running
  combined `process.roles=broker,controller`. Use an odd count (3 or 5) so the
  controller quorum has a clear majority.
- **Quorum**: every broker is a KRaft controller voter. Leader election and metadata
  replication are native to KRaft — no Zookeeper, no external coordinator.
- **Replication defaults**: `default.replication.factor=3`, `min.insync.replicas=2`,
  and the internal offsets/transaction topics replicate 3× with min-ISR 2. A topic
  created with replication factor 3 survives the loss of one broker with no data loss;
  writes with `acks=all` keep succeeding as long as two replicas stay in sync.
- **Stable identity**: a headless Service gives each pod a fixed DNS name
  (`<release>-kafka-<ordinal>.<release>-kafka-headless`), which the quorum voters and
  inter-broker replication use. `publishNotReadyAddresses` lets brokers find each other
  before any is Ready, so the quorum can bootstrap.
- **Client access**: a single ClusterIP Service on 9092 fronts all brokers as the
  bootstrap endpoint; clients then talk to the per-broker advertised addresses.
- **Per-broker storage**: each pod gets its own PVC (`volumeClaimTemplate`) — never a
  shared disk.
- **Scheduling**: a soft `podAntiAffinity` spreads brokers across nodes when possible.
  Set `affinity` to a required anti-affinity block for a hard spread on a multi-node
  cluster.
- **Disruption budget**: `podDisruptionBudget.minAvailable=2` keeps the quorum above
  majority during a voluntary drain.
- **Boundary**: losing a majority of the quorum (2 of 3) is not auto-recovered — that
  is a split-brain risk a human must resolve.

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
| `replicaCount` | `3` | Broker count = controller quorum size. Use an odd number. |
| `kraft.processRoles` | `broker,controller` | Combined KRaft roles. |
| `kraft.autoCreateTopics` | `true` | Auto-create topics on first produce. |
| `kraft.numPartitions` | `3` | Default partitions per topic. |
| `kraft.defaultReplicationFactor` | `3` | Replication factor for auto-created topics. |
| `kraft.minInsyncReplicas` | `2` | Min in-sync replicas for `acks=all` durability. |
| `kraft.offsetsTopicReplicationFactor` | `3` | |
| `kraft.transactionStateLogReplicationFactor` | `3` | |
| `kraft.transactionStateLogMinIsr` | `2` | |
| `kraft.clusterId` | `""` | Fixed cluster id, or generated + stored in a Secret if empty. |
| `kraft.heapOpts` | `-Xmx1G -Xms1G` | JVM heap per broker. |
| `primary.persistence.enabled` | `true` | Per-broker 8Gi PVC at `/var/lib/kafka`. |
| `service.port` | `9092` | PLAINTEXT client listener. |
| `extraEnvVars` | `[]` | Inject any `KAFKA_*` property the entrypoint maps. |
| `networkPolicy.enabled` | `true` | Restricts client ingress to the namespace; allows the controller port between brokers. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 2`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`, scheduling
(`affinity`/`nodeSelector`/`tolerations`/`topologySpreadConstraints`), `initContainers`,
`sidecars`, `extraVolumes`/`extraVolumeMounts`, `lifecycleHooks`, configurable probes,
and overridable security contexts.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/kafka` (the PVC) and `/tmp` are writable.

## Notes

Listeners are PLAINTEXT and reachable only inside the cluster (the NetworkPolicy
restricts client ingress to the release namespace and permits the KRaft controller port
only between brokers). SASL/TLS auth, a metrics exporter, and topic provisioning are
tracked follow-ups. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

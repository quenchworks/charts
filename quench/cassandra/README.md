# Quenchworks Cassandra

Hardened Apache Cassandra on a minimal, nonroot, 0-CVE image pinned by digest.
Runs on the hardened `openjdk-17-jre` base. The image's entrypoint generates
`cassandra.yaml` from `CASSANDRA_*` env on boot; the chart pins the image by its
signed digest and runs a clustered StatefulSet (single node by default).

## Install

```bash
helm install cs oci://ghcr.io/quenchworks/charts/cassandra
```

Tune it:

```bash
helm install cs oci://ghcr.io/quenchworks/charts/cassandra \
  --set replicaCount=3 --set config.seedCount=3 --set persistence.size=50Gi \
  --set config.maxHeapSize=4G --set config.heapNewSize=800M
```

## Connect

The runtime image has no usable `cqlsh` (no Python), so connect with a throwaway
upstream client pod:

```bash
kubectl run cqlclient --rm -it --restart=Never --image=cassandra:5.0 -- \
  cqlsh cs-cassandra 9042
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cassandra \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/cassandra --owner quenchworks`.

## Authentication

Auth is **off by default** (`AllowAllAuthenticator`) — this is an internal
deployment and the NetworkPolicy is the trust boundary. Enable login auth with:

```bash
helm install cs oci://ghcr.io/quenchworks/charts/cassandra --set auth.enabled=true
```

This sets `PasswordAuthenticator` + `CassandraRoleManager`, and Cassandra
bootstraps the default `cassandra` / `cassandra` superuser. **Rotate it
immediately:**

```sql
ALTER ROLE cassandra WITH PASSWORD = '<new-strong-password>';
```

For clusters, also raise the `system_auth` keyspace replication factor (default RF
of 1 means auth breaks if the node holding it goes down):

```sql
ALTER KEYSPACE system_auth WITH replication =
  {'class':'NetworkTopologyStrategy','<dc>': 3};
```

## Clustering

A multi-node ring forms automatically when `replicaCount > 1`. The first
`config.seedCount` pods (pod-0 .. pod-(seedCount-1)) are advertised as
`CASSANDRA_SEEDS` over the stable headless service. Cassandra recommends ~3 seeds
per DC. For multi-DC topologies set `config.endpointSnitch=GossipingPropertyFileSnitch`
and `config.dc` / `config.rack` (written to `cassandra-rackdc.properties`).

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/cassandra` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Ring size; pods join sequentially (OrderedReady). |
| `config.clusterName` | `Quench Cluster` | Must match across all nodes in a ring. |
| `config.seedCount` | `1` | Stable seed pods, clamped to `replicaCount`. |
| `config.numTokens` | `16` | vnodes per node. |
| `config.endpointSnitch` | `SimpleSnitch` | `GossipingPropertyFileSnitch` for multi-DC. |
| `config.dc` / `config.rack` | `""` | Written to rackdc.properties only when set. |
| `config.maxHeapSize` | `512M` | JVM max heap (`MAX_HEAP_SIZE`). |
| `config.heapNewSize` | `128M` | JVM young gen (`HEAP_NEWSIZE`). |
| `config.yamlExtra` | `""` | Raw `cassandra.yaml` appended verbatim. |
| `auth.enabled` | `false` | Toggle PasswordAuthenticator + CassandraRoleManager. |
| `persistence.enabled` | `true` | 16Gi PVC per pod at `/var/lib/cassandra`. |
| `service.cqlPort` | `9042` | CQL client port (ClusterIP + headless). |
| `service.internodePort` | `7000` | Gossip/storage (headless only). |
| `networkPolicy.enabled` | `true` | Ingress to internode (own pods) + CQL (clients). |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only `/var/lib/cassandra` (PVC), `/conf`, and `/var/log/cassandra`
(emptyDir) are writable. JMX (7199) is bound to localhost in the image and is
never exposed. Readiness gates on `nodetool status` reporting Up/Normal, so a pod
only takes traffic once it has actually joined the ring.

## Notes

Single standalone node by default; multi-node rings work via `replicaCount` +
`config.seedCount`. A Prometheus JMX exporter sidecar is a tracked follow-up.
Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

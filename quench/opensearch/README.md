# Quenchworks OpenSearch

Hardened [OpenSearch](https://opensearch.org/) on a minimal, nonroot, 0-CVE image
pinned by digest. Packaged on the shared `openjdk-21-jre` base (the bundled JDK is
stripped so the JRE stays the scanned CVE surface). The image writes `opensearch.yml`
from `OPENSEARCH_*` env, so the whole cluster is configured from chart values.

By default this installs a real HA cluster. Flip `mode: single` for a one-node
box when you don't need fault tolerance.

## Install

```bash
helm install os oci://ghcr.io/quenchworks/charts/opensearch
```

Then query it:

```bash
kubectl run q --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://os-opensearch:9200/_cluster/health?pretty
```

## Standalone vs HA

HA is the default: dedicated cluster-manager and data pools with node-loss
failover. For dev/test or a small footprint, run a single node instead:

```bash
# Standalone: 1 node (discovery.type=single-node), no fault tolerance
helm install os oci://ghcr.io/quenchworks/charts/opensearch \
  --set mode=single

# HA (default): 3 cluster-managers + 2 data nodes, shard replicas, auto failover
helm install os oci://ghcr.io/quenchworks/charts/opensearch
```

single mode is one pod with no shard replicas, so a node loss is downtime. HA
keeps reads and writes serving through a data-node loss and re-elects the manager
on manager loss, at the cost of running 5 nodes. See [Topology](#topology) for the
node pools, the failover table, and the quorum boundary.

## Topology

### HA mode (default)

Two node pools, each its own StatefulSet, so roles are dedicated the way a real
cluster wants them:

- **`master` pool** (3 nodes) — `node.roles: [cluster_manager]`. These hold the
  cluster state and elect the leader. Nothing else runs on them, so a data-node
  GC pause or a heavy query can't stall the election. Use an **odd** count so a
  majority is unambiguous: 3 tolerates 1 loss, 5 tolerates 2.
- **`data` pool** (2+ nodes) — `node.roles: [data, ingest]`. These hold the shards
  and their replicas. Keep it at 2 or more so every shard's replica has a home on
  a *different* node.

Nodes find each other over the headless Service: `discovery.seed_hosts` points at
the master pods' stable DNS names, and `cluster.initial_cluster_manager_nodes`
seeds the first election. Master election and shard reallocation are native to
OpenSearch, so there is no sidecar and no external controller.

New indices default to 1 replica, so with 2 data nodes each shard is written to
both — a green cluster you can lose a node from.

### Failover — what survives what

| You lose | What happens | Result |
|----------|--------------|--------|
| A **data** node | Its replicas on the surviving node(s) are promoted to primary; the StatefulSet recreates the pod, it rejoins and re-replicates. | Reads and writes keep working. Cluster goes **yellow** (no redundancy) until it rejoins, then back to **green**. Zero-touch. |
| The elected **cluster_manager** | The surviving master-eligible nodes re-elect a leader (needs a quorum). | A brief election, then normal service. Data is untouched. |
| **Quorum of the master pool** (2 of 3) | OpenSearch refuses to elect a leader — this is the split-brain guard, not a bug. | **Hard boundary.** The cluster will not self-rebuild. Bring the failed masters back and they rejoin. A human confirms; the chart does not auto-recover past this line. |

That last row is the deliberate limit: below a master majority, recovering
automatically would risk two halves each thinking they're in charge. Restore the
masters instead.

We tested exactly this on kind: created an index with `replicas=1`, indexed a doc,
killed a data node — the doc stayed readable off the replica and the node rejoined
to green; killed the elected manager — the pool re-elected within seconds and the
doc never went away.

### single mode

```yaml
mode: single
```

One node, `discovery.type=single-node`. No fault tolerance, but it skips the
multi-node bootstrap checks (and the `vm.max_map_count` init below), so it's the
lightest thing that runs. This is the pre-0.1 layout, unchanged.

## `vm.max_map_count`

OpenSearch's multi-node bootstrap check needs the host sysctl `vm.max_map_count`
at 262144 or higher, or the node refuses to start. HA mode runs a short privileged
init container that raises it (and *only* raises it — it never lowers a node that's
already tuned higher). If your nodes are pre-tuned or you set it through the kubelet,
turn it off:

```yaml
sysctls:
  enabled: false
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/opensearch \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/opensearch \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/opensearch` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `mode` | `ha` | `ha` = clustered; `single` = one node. |
| `config.clusterName` | `quench-opensearch` | |
| `config.securityDisabled` | `true` | Security plugin isn't in the hardened image; the NetworkPolicy is the boundary. |
| `config.extraConfig` | `""` | Extra `opensearch.yml` lines, appended to every node. |
| `sysctls.enabled` | `true` | Privileged init raises `vm.max_map_count` (HA only). |
| `master.replicaCount` | `3` | Cluster-manager pool. Use an odd count for a clean quorum. |
| `master.heapSize` | `256m` | Masters do little; a small heap is plenty. |
| `master.persistence.size` | `8Gi` | Per-pod PVC for cluster state. |
| `data.replicaCount` | `2` | Data pool. Keep >= 2 so a replica has a home. |
| `data.heapSize` | `512m` | JVM heap (`-Xms`/`-Xmx`). |
| `data.persistence.size` | `16Gi` | Per-pod PVC for shards. |
| `single.*` | — | heap/persistence/resources for `mode: single`. |
| `service.httpPort` | `9200` | REST API (client Service across all nodes). |
| `service.transportPort` | `9300` | Node transport (headless Service). |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace; node-to-node transport always allowed. |
| `podDisruptionBudget.enabled` | `true` | HA pins the master pool at quorum; single uses `minAvailable`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). A soft `podAntiAffinity` spreads each pool across
nodes by default; set `.Values.affinity` to take over.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Config, data, and logs live on the writable `/data` volume; the JVM's
temp dir is routed there too, so nothing needs a writable rootfs. The one exception
is the `vm.max_map_count` init, which is privileged on purpose and only touches a
node sysctl.

The security plugin is not bundled (its opensaml jar shades a jackson we can't
patch to 0-CVE), so TLS/auth is off by construction — run this behind the
NetworkPolicy on an internal network.

## Notes

Backups are not part of failover — a replicated cluster survives node loss, not a
bad delete or a corrupt index. A snapshot CronJob to object storage is a tracked
follow-up. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

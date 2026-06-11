# Charts roadmap

What each chart supports today, and what is planned. Everything is authored clean-room from each
application's own upstream docs.

## Redis

Shipping now:

- Standalone and replication architectures (primary plus `replicaof` read replicas)
- Auth via `requirepass` with a generated or user-supplied Secret
- Custom `redis.conf` through a ConfigMap, plus `extraFlags` and `existingConfigmap`
- In-transit TLS using a provided certificate Secret
- Prometheus metrics through a hardened `redis-exporter` sidecar we build ourselves, with an
  optional ServiceMonitor and PrometheusRule
- ServiceAccount (token automount off) and optional minimal RBAC
- Headless services for stable network identities, HPA for replicas
- NetworkPolicy, PodDisruptionBudget, nonroot, read-only root filesystem, dropped capabilities
- Image pinned by digest through `quench-common`

### Planned: Sentinel high availability

Sentinel is deliberately not in this first pass. It is a separate control plane: a sentinel
process alongside each node, quorum-based failover, and clients that must speak the Sentinel
protocol. Doing it correctly needs failover handling and a real multi-node cluster to validate, so
it gets its own focused, tested change rather than being bolted on untested.

Plan when we pick it up:

1. Add a `sentinel` container to the replica pods, reading the same config and TLS material.
2. Expose a sentinel service so clients can discover the current primary.
3. Validate a failover in kind (kill the primary, confirm a replica is promoted) before release.
4. Document the client connection pattern in the chart README.

# Quenchworks cnpg-stack

Operator-managed HA PostgreSQL in one install:

- the [CloudNativePG](https://cloudnative-pg.io) operator,
- a `Cluster`: a primary plus streaming replicas, automated failover, metrics on port
  9187 of every instance,
- a PgBouncer `Pooler` in front of the primary, running the catalog `pgbouncer` image.

Every image is minimal, nonroot, 0-CVE, cosign-signed and pinned by digest. For HA
without an operator, see [postgres-ha-stack](../postgres-ha-stack) (Patroni).

## Install

The operator's CRDs, ClusterRole and webhooks are cluster-wide: one operator per cluster.

```bash
helm install pg oci://ghcr.io/quenchworks/charts/cnpg-stack -n db --create-namespace
kubectl -n db get cluster pg-pg
kubectl -n db get secret pg-pg-app -o jsonpath='{.data.uri}' | base64 -d; echo
```

Apps connect to `pg-pg-pooler-rw:5432` (PgBouncer to the primary), or directly to
`pg-pg-rw` (primary), `pg-pg-ro` (replicas) and `pg-pg-r` (any instance).

The Cluster and Pooler are applied by a post-install/upgrade hook Job, because the
operator's admission webhook is not serving yet when Helm applies the release. They are
not release objects, so `helm uninstall` keeps the database and its volumes. Remove them
with `kubectl delete cluster pg-pg` and `kubectl delete pooler pg-pg-pooler-rw`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `cluster.enabled` | `true` | Create the Cluster |
| `cluster.instances` | `3` | Primary plus replicas |
| `cluster.storage.size` | `8Gi` | Per instance |
| `cluster.storage.storageClass` | `""` | Default class when empty |
| `cluster.database`, `cluster.owner` | `app` | Created at bootstrap; password in `<release>-pg-app` |
| `cluster.extraSpec` | `{}` | Merged into the Cluster spec (parameters, backup, affinity) |
| `pooler.enabled` | `true` | Create the PgBouncer Pooler |
| `pooler.instances` | `2` | Pooler replicas |
| `pooler.poolMode` | `session` | `session` or `transaction` |
| `pooler.parameters` | `{}` | PgBouncer parameters |
| `cloudnative-pg.*` | | Passed to the [cloudnative-pg](../cloudnative-pg) chart (its `postgresImage` is the database image) |

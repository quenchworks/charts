# Quenchworks mysql-ha-stack

Operator-managed HA MySQL-compatible database in one install:

- [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator), which runs
  MariaDB through `MariaDB`, `Database`, `User`, `Grant` and `Backup` resources,
- a 3-node [Galera](https://galeracluster.com) cluster: synchronous multi-primary
  replication and automatic recovery of failed nodes. `galera.metrics` adds
  `mysqld_exporter` when the Prometheus Operator is installed.

Every image (operator, MariaDB, mysqld_exporter) is minimal, nonroot, 0-CVE,
cosign-signed and pinned by digest. For an operator-free MySQL, see the
[mysql](../mysql) and [mariadb](../mariadb) charts.

## Install

The operator's CRDs, ClusterRole and webhooks are cluster-wide: one operator per cluster.

```bash
helm install db oci://ghcr.io/quenchworks/charts/mysql-ha-stack -n db --create-namespace
kubectl -n db get mariadb db-db
kubectl -n db get secret db-db-user -o jsonpath='{.data.password}' | base64 -d; echo
```

Apps connect to `db-db:3306` (any node) or `db-db-primary:3306` (one write node), as user
`app`, database `app`.

The MariaDB resource is applied by a post-install/upgrade hook Job, because the
operator's admission webhook is not serving yet when Helm applies the release. It is not
a release object, so `helm uninstall` keeps the database and its volumes. Remove it with
`kubectl delete mariadb db-db`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `galera.enabled` | `true` | Create the MariaDB Galera cluster |
| `galera.replicas` | `3` | Nodes; 3 keeps quorum through one loss |
| `galera.storage.size` | `8Gi` | Per node |
| `galera.storage.storageClass` | `""` | Default class when empty |
| `galera.database`, `galera.username` | `app` | Created at bootstrap; passwords in `<release>-db-user` and `<release>-db-root` |
| `galera.metrics` | `false` | mysqld_exporter and a ServiceMonitor; needs the Prometheus Operator CRDs |
| `galera.extraSpec` | `{}` | Merged into the MariaDB spec (myCnf, affinity, galera.sst) |
| `mariadb-operator.*` | | Passed to the [mariadb-operator](../mariadb-operator) chart |

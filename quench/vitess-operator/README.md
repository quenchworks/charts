# Quenchworks vitess-operator

The [Vitess Operator](https://github.com/planetscale/vitess-operator) 2.17.1 on
the QuenchWorks image (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). It runs Vitess, horizontally sharded MySQL, from
`VitessCluster` resources: an etcd topology server, vtctld, vtgate per cell,
vttablet with mysqld per shard, vtorc, resharding and backups.

The chart installs the eight `planetscale.com` CRDs from the release tag, the
operator Deployment, upstream's RBAC and the two PriorityClasses.

## Install

```bash
helm install vitess-operator oci://ghcr.io/quenchworks/charts/vitess-operator -n vitess --create-namespace
```

Then a one-shard cluster in the same namespace (the operator watches only its
own namespace by default):

```yaml
apiVersion: planetscale.com/v2
kind: VitessCluster
metadata: { name: main }
spec:
  images:
    vtctld: vitess/lite:v24.0.5-mysql80
    vtgate: vitess/lite:v24.0.5-mysql80
    vttablet: vitess/lite:v24.0.5-mysql80
    vtorc: vitess/lite:v24.0.5-mysql80
    vtbackup: vitess/lite:v24.0.5-mysql80
    mysqld: { mysql80Compatible: vitess/lite:v24.0.5-mysql80 }
  cells:
    - name: zone1
      gateway:
        authentication: { static: { secret: { name: main-config, key: users.json } } }
        replicas: 1
  keyspaces:
    - name: app
      durabilityPolicy: none
      vitessOrchestrator: {}
      partitionings:
        - equal:
            parts: 1
            shardTemplate:
              databaseInitScriptSecret: { name: main-config, key: init_db.sql }
              tabletPools:
                - cell: zone1
                  type: replica
                  replicas: 2
                  dataVolumeClaimTemplate:
                    accessModes: [ReadWriteOnce]
                    resources: { requests: { storage: 10Gi } }
```

`main-config` holds `users.json` (vtgate's static logins) and `init_db.sql`
(see upstream's `test/endtoend/operator/101_initial_cluster.yaml` for a
complete one).

## Values

| Key | Default | Notes |
|---|---|---|
| `watchAllNamespaces` | `false` | `false` watches only the release namespace, like upstream's deploy |
| `defaultEtcdImage` | `""` | `--default_etcd_image`; empty keeps upstream's `quay.io/coreos/etcd` |
| `priorityClasses.create` | `true` | `vitess-operator-control-plane` and `vitess` (cluster-wide names) |
| `logVerbosity` | `2` | glog `-v` |
| `extraArgs` | `[]` | more operator flags, e.g. `--cache_invalidate_interval=5m` |
| `rbac.create` | `true` | upstream's ClusterRole plus the backup-storage Role |

## Notes

- The Vitess components run upstream's `vitess/lite` images. The operator
  expects binaries under `/vt/bin` and copies them with `cp` in init
  containers; the QuenchWorks `vitess` image (binaries in `/usr/bin`, no
  shell) is not a drop-in yet. Only the operator image is hardened in this
  release.
- The etcd lockserver runs upstream's `quay.io/coreos/etcd` by default: the
  operator starts `/usr/local/bin/etcd`, and the QuenchWorks etcd image
  installs `/usr/bin/etcd`.
- Leader election uses a ConfigMap owned by the operator pod, so extra replicas
  wait as standbys.
- The PriorityClass names are fixed (VitessCluster components default to
  `vitess`). Install the chart once per cluster, or set
  `priorityClasses.create: false` for further installs.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/` yourself before upgrading across operator releases.

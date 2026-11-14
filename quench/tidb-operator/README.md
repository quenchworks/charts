# Quenchworks tidb-operator

The [TiDB Operator](https://github.com/pingcap/tidb-operator) 1.6.6 on the QuenchWorks image
(built from source, nonroot, CVE-gated at build, pinned by digest, cosign-signed). The operator
runs TiDB clusters (PD, TiKV and the MySQL-compatible TiDB servers) from `TidbCluster`
resources, with scaling, rolling upgrades and automatic failover.

The chart installs the 10 CRDs and upstream's chart with its defaults: the controller manager,
its service account and its cluster role. The operator image also runs each cluster's discovery
service.

## Install

```bash
helm install tidb-operator oci://ghcr.io/quenchworks/charts/tidb-operator -n tidb-admin --create-namespace
```

Then a cluster:

```yaml
apiVersion: pingcap.com/v1alpha1
kind: TidbCluster
metadata: { name: basic, namespace: tidb }
spec:
  version: v8.5.8
  pd:   { baseImage: pingcap/pd,   replicas: 3, requests: { storage: 10Gi } }
  tikv: { baseImage: pingcap/tikv, replicas: 3, requests: { storage: 100Gi } }
  tidb: { baseImage: pingcap/tidb, replicas: 2, service: { type: ClusterIP } }
```

Connect with any MySQL client to `basic-tidb.tidb:4000`.

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` | `ghcr.io/quenchworks/images/tidb-operator` | operator and discovery |
| `image.digest` | pinned | |
| `backupManagerImage` | `pingcap/tidb-backup-manager:v1.6.6` | used only by `Backup` and `Restore` |

## Notes

- Only the operator is a QuenchWorks image. PD, TiKV, TiDB, TiFlash and the backup manager run
  PingCAP's images (`spec.*.baseImage`).
- The operator is cluster-scoped, as upstream's default. One install per cluster: the cluster
  role keeps upstream's name, prefixed with the release name.
- The TiDB scheduler extender, the advanced StatefulSet controller and the admission webhook
  (all off in upstream's defaults) are not part of this chart; the image carries the scheduler
  and webhook binaries.
- Helm installs the CRDs on first install and never upgrades or deletes them. Apply the new
  `crds/` with `kubectl replace` (they exceed the size limit of client-side apply) before
  upgrading across operator releases.

# Quenchworks rook-ceph

The [Rook](https://rook.io) Ceph operator: it runs [Ceph](https://ceph.io) clusters on
Kubernetes through CRDs (CephCluster, CephObjectStore, CephBlockPool, CephFilesystem,
ObjectBucketClaims and more). The operator image is built from source; the Ceph image is
Ceph 20 (Tentacle) from Wolfi packages. Both are minimal, 0-CVE, cosign-signed and pinned
by digest.

Ceph CSI is included: the chart runs the ceph-csi-operator, Rook creates its driver
resources, and the operator runs the cephcsi driver with the CSI sidecars, all QuenchWorks
images. Set `csi.enabled: false` for object storage only.

## Install

One operator per cluster (its CRDs and ClusterRoles are cluster-wide):

```bash
helm install rook oci://ghcr.io/quenchworks/charts/rook-ceph -n rook-ceph --create-namespace
```

Then create a CephCluster with the QuenchWorks ceph image (the chart's notes print the
exact pinned reference):

```yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata: {name: ceph, namespace: rook-ceph}
spec:
  cephVersion:
    image: ghcr.io/quenchworks/images/ceph:20.2.4@sha256:...
  dataDirHostPath: /var/lib/rook
  mon: {count: 3}
  mgr: {count: 2}
  storage: {useAllNodes: true, useAllDevices: true}
```

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `config` | see values.yaml | `rook-ceph-operator-config` settings (ROOK_LOG_LEVEL, ROOK_CEPH_ALLOW_LOOP_DEVICES, ...) |
| `currentNamespaceOnly` | `false` | Watch CephClusters only in the release namespace |
| `csi.enabled` | `true` | Run the ceph-csi-operator, cephcsi and the CSI sidecars |
| `csi.images` | QuenchWorks images by digest | Driver and sidecar images Rook hands the CSI operator |
| `cephImage` | ceph 20.2.4 by digest | The image to use in CephClusters (shown in the notes) |
| `resources` | 100m / 128Mi | Operator resources |

The CRDs (from Rook v1.21.0) install from the chart's `crds/` directory and are not
removed on uninstall. The RBAC is Rook's own, rendered into the release namespace; its
object names are fixed because the operator looks them up by name.

## How it is tested

The release gate attaches a loop device on the runner, shares `/dev` and `/run/udev` into
a kind node (ceph-volume needs udev data for the device), and requires a one-mon,
one-OSD CephCluster to reach Ready with the OSD up, then an S3 bucket, put and get through
a CephObjectStore gateway, then an RBD PersistentVolumeClaim through Ceph CSI that one pod
writes and a second pod reads back.

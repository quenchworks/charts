# Quenchworks dragonfly-operator

The [Dragonfly Operator](https://github.com/dragonflydb/dragonfly-operator) 1.8.0
on QuenchWorks images (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). It runs [Dragonfly](https://www.dragonflydb.io), a Redis-
and Memcached-compatible in-memory store, from `Dragonfly` resources: a primary
with replicas and automatic failover, snapshots to a volume or S3, TLS and ACLs.

The chart installs the `dragonflies.dragonflydb.io` CRD and upstream's RBAC from
the release tag, and the operator Deployment.

## Install

```bash
helm install dragonfly-operator oci://ghcr.io/quenchworks/charts/dragonfly-operator -n dragonfly-operator-system --create-namespace
```

## Values

| Key | Default | Notes |
|---|---|---|
| `dragonflyImage` | our `dragonfly` 1.40.2 | `--dragonfly-image`: every Dragonfly without `spec.image` runs it; `null` keeps upstream's |
| `watchCurrentNamespace` | `false` | `--watch-current-namespace` |
| `replicaCount` | `1` | leader election is on; extra replicas are standbys |
| `extraArgs` | `[]` | more operator flags |
| `rbac.create` | `true` | upstream's ClusterRole and leader-election Role |

## Notes

- Upstream's manifest runs a kube-rbac-proxy sidecar (a quay.io image) in front
  of the metrics port. This chart does not: metrics are plain HTTP on 8080
  (Service `dragonfly-operator-metrics`), and the proxy's TokenReview and
  SubjectAccessReview permissions are left out.
- Object names are upstream's (`dragonfly-operator-*`), so install it once per
  cluster.
- Helm installs the CRD on first install and never upgrades or deletes it. Apply
  the new `crds/crds.yaml` yourself before upgrading across operator releases.

# Quenchworks Percona XtraDB Cluster Operator

The [Percona Operator for MySQL based on Percona XtraDB Cluster](https://github.com/percona/percona-xtradb-cluster-operator)
runs synchronous multi-primary MySQL (Galera) clusters on Kubernetes, with
HAProxy or ProxySQL in front, backups and point-in-time recovery. This chart
installs the operator built from source by QuenchWorks (nonroot, 0 fixable CVEs,
pinned by digest, cosign-signed) and its CRDs. The database, proxy and backup
pods it creates run Percona's own images, named in each cluster resource.

## Install

```bash
helm install pxc-operator oci://ghcr.io/quenchworks/charts/percona-xtradb-cluster-operator
```

Then create a `PerconaXtraDBCluster` in the same namespace, starting from
upstream's `deploy/cr-minimal.yaml` or `deploy/cr.yaml` for this version.

## Values

| Key | Default | Notes |
|---|---|---|
| `logLevel` | `INFO` | `VERBOSE`, `DEBUG`, `INFO` or `ERROR` |
| `telemetry` | `false` | upstream's usage telemetry to Percona |
| `featureGates` | `""` | `PXCO_FEATURE_GATES` |
| `maxConcurrentReconciles` | `1` | clusters reconciled in parallel |

## Notes

- Set `spec.crVersion` to the chart's appVersion. The operator's own image is
  the init image of every pod it creates, and for another crVersion it rewrites
  that reference by tag, which a digest-pinned image does not carry. To run
  another version, set `spec.initContainer.image`.
- The operator watches only its own namespace, with upstream's namespaced Role.
  Install one release per namespace that holds clusters.
- Keep the operator container named `percona-xtradb-cluster-operator`: the
  operator finds its image by that name.
- The CRDs are installed from `crds/` on first install only; Helm does not
  upgrade them. Apply the new `crds/crd.yaml` by hand before upgrading.

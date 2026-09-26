# Quenchworks MariaDB Operator

[MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator) runs
MariaDB and Galera clusters on Kubernetes from custom resources: `MariaDB`,
`Database`, `User`, `Grant`, `Backup`, `Restore` and more. The CRDs ship in
this chart's `crds/`. The operator image is nonroot, 0 fixable CVEs, pinned by
digest and cosign-signed, and the MariaDB pods it creates default to the
QuenchWorks mariadb image.

## Install

```bash
helm install mariadb-operator oci://ghcr.io/quenchworks/charts/mariadb-operator \
  -n mariadb-operator --create-namespace
```

Then create a server:

```yaml
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata:
  name: mariadb
spec:
  rootPasswordSecretKeyRef:
    name: mariadb-root
    key: password
    generate: true
  storage:
    size: 1Gi
```

## Values

| Key | Default | Notes |
|---|---|---|
| `config.mariadbImage` | QuenchWorks mariadb 12.3.3 | image for MariaDB pods |
| `config.exporterImage` | QuenchWorks mysqld-exporter | image for the metrics sidecar |
| `currentNamespaceOnly` | `false` | watch only the release namespace |
| `replicaCount` | `1` | more than one enables leader election |

## Notes

- This release has no admission webhook (upstream's `webhook` and
  `cert-controller` components), so the API server does not validate MariaDB
  resources before the operator reads them.
- MaxScale is BSL-licensed and has no QuenchWorks image. The MaxScale images
  default to upstream's and are only pulled for a `MaxScale` resource.
- Helm installs CRDs from `crds/` but never upgrades them. Apply the new
  `crds/crds.yaml` by hand when you upgrade the chart.

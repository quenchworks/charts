# Quenchworks clickhouse-operator

The [Altinity ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)
0.27.4 on QuenchWorks images (built from source, nonroot, CVE-gated at build,
pinned by digest, cosign-signed). It runs ClickHouse installations and ClickHouse
Keeper from Kubernetes resources: shards and replicas as StatefulSets, schema
propagation to new replicas, rolling configuration changes and upgrades.

The chart installs the four CRDs (`ClickHouseInstallation`,
`ClickHouseInstallationTemplate`, `ClickHouseOperatorConfiguration`,
`ClickHouseKeeperInstallation`), the operator with its metrics exporter, upstream's
RBAC, and upstream's default operator and ClickHouse/Keeper configuration, all
from the release tag's install bundle.

## Install

```bash
helm install clickhouse-operator oci://ghcr.io/quenchworks/charts/clickhouse-operator -n clickhouse --create-namespace
```

Then a one-node ClickHouse:

```yaml
apiVersion: clickhouse.altinity.com/v1
kind: ClickHouseInstallation
metadata: { name: main }
spec:
  configuration:
    clusters: [{ name: main, layout: { shardsCount: 1, replicasCount: 1 } }]
```

## Values

| Key | Default | Notes |
|---|---|---|
| `watchNamespaces` | `[]` | `WATCH_NAMESPACES` (names or regexps); empty watches every namespace |
| `metricsExporter.enabled` | `true` | Prometheus metrics for every managed ClickHouse on port 8888 |
| `metricsExporter.image` | our image | pinned by digest |
| `rbac.create` | `true` | upstream's ClusterRole and Role |

The operator's own metrics are on port 9999; Service `<release>-clickhouse-operator-metrics`
exposes both ports.

## Notes

- ClickHouse pods run upstream's `clickhouse/clickhouse-server` image unless a
  `podTemplate` sets one. The default is compiled into the operator, so the chart
  cannot change it. Only the operator and the metrics exporter are QuenchWorks
  images in this release.
- The operator logs in to every ClickHouse it manages as `clickhouse_operator`.
  Upstream ships a fixed password for that user; this chart generates one into
  Secret `clickhouse-operator` on first install and keeps it. The name is fixed
  by the operator's configuration, so run one operator per namespace.
- To change the operator configuration, edit the `files/` tree in a fork of this
  chart, or apply a `ClickHouseOperatorConfiguration` resource.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across operator
  releases.

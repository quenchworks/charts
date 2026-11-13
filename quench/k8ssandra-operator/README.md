# Quenchworks k8ssandra-operator

The [K8ssandra Operator](https://github.com/k8ssandra/k8ssandra-operator) 1.34.0
and [cass-operator](https://github.com/k8ssandra/cass-operator) 1.33.1 on the
QuenchWorks images (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). K8ssandra Operator runs Apache Cassandra clusters from
`K8ssandraCluster` resources, with Medusa backups, Reaper repairs and Stargate;
it creates `CassandraDatacenter` resources, which cass-operator runs as
StatefulSets.

The chart installs the 14 CRDs of both operators, both Deployments, upstream's
RBAC, the operators' image config, and the mutating and validating webhooks.

## Install

```bash
helm install k8ssandra-operator oci://ghcr.io/quenchworks/charts/k8ssandra-operator -n k8ssandra-operator --create-namespace
```

Then a cluster, in the same namespace:

```yaml
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata: { name: main }
spec:
  cassandra:
    serverVersion: "4.1.9"
    datacenters:
      - metadata: { name: dc1 }
        size: 3
        storageConfig:
          cassandraDataVolumeClaimSpec:
            accessModes: [ReadWriteOnce]
            resources: { requests: { storage: 50Gi } }
```

The superuser login is in Secret `main-superuser` (`username`, `password`).

## Values

| Key | Default | Notes |
|---|---|---|
| `image.digest` | pinned | the k8ssandra-operator image |
| `cassOperator.image.digest` | pinned | the cass-operator image |
| `cassOperator.resources` | 100m / 64Mi, limit 500m / 256Mi | cass-operator pod |
| `webhook.failurePolicy` | `Fail` | `Ignore` lets changes through while an operator is down |
| `watchNamespaces` | `[]` | `WATCH_NAMESPACE` for both operators; empty watches every namespace |
| `replicaCount` | `1` | k8ssandra-operator; leader election is always on, extra replicas are standbys |
| `imageConfig` | upstream's | the images the operators put in Cassandra pods; `""` skips the ConfigMap |

## Notes

- Cassandra, Medusa, Reaper and the logger sidecar run upstream images
  (`k8ssandra/cass-management-api`, `k8ssandra/medusa`,
  `thelastpickle/cassandra-reaper`, `k8ssandra/system-logger`), chosen by the
  `imageConfig` ConfigMap both operators read. Only the two operator images are
  hardened in this release.
- One install per cluster: the ClusterRoles and ClusterRoleBindings keep
  upstream's names.
- k8ssandra-operator runs in control-plane mode (`K8SSANDRA_CONTROL_PLANE=true`).
  Multi-cluster setups with data-plane clusters are not covered by this chart.
- The chart generates one webhook CA and a serving certificate per operator
  (Secrets `<release>-webhook-tls` and `<release>-cass-operator-webhook-tls`) and
  keeps them across upgrades, in place of upstream's cert-manager Issuers. With
  `failurePolicy: Fail`, changes are refused while an operator is down and for a
  few seconds right after install: retry the apply.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/` yourself before upgrading across operator releases.

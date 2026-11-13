# Quenchworks opensearch-operator

The [OpenSearch Operator](https://github.com/opensearch-project/opensearch-k8s-operator)
3.0.0 on the QuenchWorks image (built from source, nonroot, CVE-gated at build,
pinned by digest, cosign-signed). It runs OpenSearch clusters and OpenSearch
Dashboards from `OpenSearchCluster` resources: node pools as StatefulSets,
generated TLS, the security plugin's users, roles and tenants, index and
component templates, ISM and snapshot policies, rolling upgrades and scaling.

The chart installs the ten `opensearch.org` CRDs from the release tag, the
operator Deployment, upstream's RBAC and the validating webhooks.

## Install

```bash
helm install opensearch-operator oci://ghcr.io/quenchworks/charts/opensearch-operator -n opensearch-system --create-namespace
```

Then a cluster:

```yaml
apiVersion: opensearch.org/v1
kind: OpenSearchCluster
metadata: { name: main }
spec:
  general: { serviceName: main, version: "3.2.0" }
  security:
    tls:
      transport: { generate: true, perNode: true }
      http: { generate: true }
  nodePools:
    - { component: nodes, replicas: 3, diskSize: 30Gi, roles: [cluster_manager, data] }
```

The admin login is in Secret `main-admin-password` (`username`, `password`).

## Values

| Key | Default | Notes |
|---|---|---|
| `webhook.enabled` | `true` | validating webhooks for every `opensearch.org` resource |
| `webhook.failurePolicy` | `Fail` | `Ignore` lets changes through while the operator is down |
| `watchNamespaces` | `[]` | `--watch-namespace`; empty watches every namespace |
| `logLevel` | `info` | `--loglevel`: debug, info, warn, error |
| `extraArgs` | `[]` | more operator flags, e.g. `--max-concurrent-reconciles=2` |
| `replicaCount` | `1` | leader election is always on; extra replicas are standbys |
| `rbac.create` | `true` | upstream's ClusterRole, the node-attributes ClusterRole and a leader-election Role |

## Notes

- OpenSearch itself runs upstream's `docker.io/opensearchproject/opensearch`
  image (and `busybox` for the init container) by default. The operator expects
  the official image's layout under `/usr/share/opensearch`, its entrypoint,
  bash and curl, and runs it as uid 1000; the QuenchWorks `opensearch` image
  (uid 1001, configured by environment) is not a drop-in yet. Set
  `spec.general.image` per cluster to choose another image. Only the operator
  image is hardened in this release.
- Only the current `opensearch.org/v1` API is served (`--enable-legacy-api=false`).
  Resources in the deprecated `opensearch.opster.io` group are not migrated.
- The chart generates the webhook CA and serving certificate once (Secret
  `<release>-webhook-tls`) and keeps them across upgrades. With
  `failurePolicy: Fail`, changes are refused while the operator is down and for
  a few seconds right after install: retry the apply.
- Metrics are served over HTTPS on 8443 and need a bearer token allowed to read
  `/metrics` (TokenReview and SubjectAccessReview).
- `spec.general.setVMMaxMapCount` (default on) runs a privileged init container
  that sets `vm.max_map_count`. On clusters that forbid privileged pods, set it
  on the nodes and turn the option off.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/` yourself before upgrading across operator releases.

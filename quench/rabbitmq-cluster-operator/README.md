# Quenchworks rabbitmq-cluster-operator

The [RabbitMQ Cluster Operator](https://github.com/rabbitmq/cluster-operator)
2.23.3 on the QuenchWorks image (built from source, nonroot, CVE-gated at build,
pinned by digest, cosign-signed). It provisions, scales and upgrades RabbitMQ
clusters from `RabbitmqCluster` resources: a StatefulSet, Services, a generated
default user, configuration and rolling upgrades.

The chart installs the `rabbitmqclusters.rabbitmq.com` CRD from the release tag,
the operator Deployment and upstream's RBAC.

## Install

```bash
helm install rabbitmq-operator oci://ghcr.io/quenchworks/charts/rabbitmq-cluster-operator -n rabbitmq-system --create-namespace
```

Then a cluster:

```yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata: { name: main }
spec: { replicas: 3 }
```

The login is in Secret `main-default-user` (`username`, `password`).

## Values

| Key | Default | Notes |
|---|---|---|
| `rabbitmqImage` | `""` | `DEFAULT_RABBITMQ_IMAGE`; empty keeps upstream's `rabbitmq:4.3.4-management` |
| `watchNamespaces` | `[]` | `OPERATOR_SCOPE_NAMESPACE`; empty watches every namespace |
| `logLevel` | `info` | `--zap-log-level` |
| `extraArgs` | `[]` | more operator flags, e.g. `--metrics-secure` |
| `replicaCount` | `1` | leader election is always on; extra replicas are standbys |
| `rbac.create` | `true` | upstream's ClusterRole plus a leader-election Role |

## Notes

- RabbitMQ itself runs upstream's Docker Hub image by default. The operator runs
  RabbitMQ as uid 999 with the official image's file layout and init scripts,
  and the QuenchWorks `rabbitmq` image (uid 1001) is not a drop-in yet.
  Only the operator image is hardened in this release.
- The defaulting and validating webhook is on: it is the only place the operator
  fills in `spec.image`. The chart generates its CA and serving certificate once
  (Secret `<release>-webhook-tls`) and keeps them across upgrades; both webhook
  configurations carry that CA. `failurePolicy` is `Fail`, so RabbitmqCluster
  changes are refused while the operator is down, and for a few seconds right
  after install (`connection refused` from the webhook): retry the apply.
- Helm installs the CRD on first install and never upgrades or deletes it. Apply
  the new `crds/crds.yaml` yourself before upgrading across operator releases.

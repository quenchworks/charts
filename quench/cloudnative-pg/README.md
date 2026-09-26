# cloudnative-pg

The CloudNativePG operator: PostgreSQL clusters on Kubernetes with streaming
replicas, automated failover, rolling updates and backups, declared as a `Cluster`
resource. The operator and the PostgreSQL pods both run QuenchWorks images:
hardened, 0-CVE, pinned by digest and cosign-signed.

## Install

```sh
helm install cnpg oci://ghcr.io/quenchworks/charts/cloudnative-pg --namespace cnpg-system --create-namespace
```

Then create a cluster in any namespace:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg
spec:
  instances: 3
  postgresUID: 1001
  postgresGID: 1001
  storage:
    size: 10Gi
```

Applications use the `pg-rw` Service (primary) or `pg-ro` (replicas) with the
credentials in the `pg-app` Secret.

## How it runs

- **One image, two roles.** The operator copies its own binary into each PostgreSQL
  pod through a bootstrap initContainer, where it runs as the instance manager.
  `OPERATOR_IMAGE_NAME` is set to this chart's digest-pinned image for that reason.
- **PostgreSQL image.** Clusters without `spec.imageName` use the QuenchWorks
  postgresql image (`postgresImage`), referenced by tag and digest: CloudNativePG
  reads the major version from the tag. That image runs as uid 1001, so set
  `postgresUID` and `postgresGID` to 1001 (CloudNativePG defaults to 26).
- **Webhooks.** The operator issues its own webhook certificate and injects the CA
  into the webhook configurations. Their names, the `cnpg-webhook-service` Service
  and the `cnpg-default-monitoring` ConfigMap are upstream's fixed names: install
  one operator per cluster.
- **CRDs** (eleven, from 1.30.1) are in `crds/`. Helm installs them once and never
  upgrades them; apply a newer chart's `crds/` with `kubectl apply --server-side`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `postgresImage` | postgresql 18.6 | default `spec.imageName` for clusters |
| `config` | `{}` | operator settings (INHERITED_LABELS, WATCH_NAMESPACE, ...) |
| `replicaCount` | `1` | operator replicas (leader-elected) |
| `maxConcurrentReconciles` | `10` | reconcile workers |

## Release gate

On kind, the gate installs the operator, creates a one-instance `Cluster` on the
default image, waits for it to be Ready, and runs a query as the generated `app`
user over TCP.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

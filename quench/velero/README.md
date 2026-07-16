# Quenchworks Velero

Hardened [Velero](https://github.com/vmware-tanzu/velero), the CNCF backup and
disaster-recovery controller for Kubernetes. It backs up cluster resources and
persistent volumes to object storage and restores them on demand. This chart
runs the velero server as a single-replica Deployment on a minimal, nonroot,
0-CVE image built from source, cosign-signed and pinned by digest.

The container runs as uid 1001 with a read-only root filesystem and every Linux
capability dropped. It writes only to in-memory `emptyDir` mounts (`/plugins`,
`/scratch`, `/tmp`), so there is no writable layer at runtime and no PVC. The
image ships nothing but the static Go binary and a CA bundle, so the attack
surface is the binary and its TLS trust store, not a shell or package manager.

## What this chart does and does not install

The server on its own is inert. To take a real backup you also need three things
that live outside the server image: an object-store bucket, a provider plugin
that knows how to talk to that bucket, and credentials for it. This chart wires
all three but ships none of them, because they are specific to your cloud.

By default the chart installs the CRDs, the server Deployment, a ServiceAccount,
and a cluster-wide RBAC binding. It does not create a `BackupStorageLocation` or
inject a plugin unless you ask it to. Installed that way the server boots idle:
it runs, reconciles nothing, and waits for a storage location to appear. That is
a valid first-install state and the one the CI gate exercises.

## Install

Idle install (no object store yet):

```bash
helm install velero oci://ghcr.io/quenchworks/charts/velero --namespace velero --create-namespace
```

Full install against an S3 bucket, with the AWS plugin and credentials wired in,
is shown under [Backing up to S3](#backing-up-to-s3) below.

Velero is CRD-heavy. Helm installs the CRDs from the chart's `crds/` directory
before the templates on first install. Helm does not upgrade or delete CRDs on
`helm upgrade` or `helm uninstall`, which is deliberate so an uninstall never
takes your Backup and Restore objects with it. When you move to a new Velero
minor version, apply the updated CRDs yourself before upgrading the release.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/velero \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and a SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/velero --owner quenchworks`.
Use `gh attestation`, not `cosign download sbom`; the SBOM and provenance are
attached as attestations, not as a separate SBOM artifact.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/velero` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | The server is a singleton controller with no leader election. Keep at 1. |
| `extraArgs` | `[]` | Extra flags appended to `velero server` (e.g. `--log-level=debug`). |
| `uploaderType` | `kopia` | Data mover for filesystem/CSI backups. `restic` only for legacy setups. |
| `features` | `""` | Comma-separated Velero feature gates, passed as `--features` when set. |
| `backupStorageLocation.create` | `false` | Create a BSL. When false the server boots idle. |
| `backupStorageLocation.name` | `default` | BSL name; also the server's default target. |
| `backupStorageLocation.default` | `true` | Mark this BSL as the default backup target. |
| `backupStorageLocation.provider` | `""` | Object-store provider (`aws`, `gcp`, `azure`, ...). Must match a plugin. |
| `backupStorageLocation.bucket` | `""` | Bucket the backups are written to. |
| `backupStorageLocation.prefix` | `""` | Optional key prefix within the bucket. |
| `backupStorageLocation.config` | `{}` | Provider config passed to `spec.config` (region, s3Url, s3ForcePathStyle, ...). |
| `credentials.existingSecret` | `""` | Secret holding cloud credentials, referenced by the BSL via `spec.credential`. |
| `credentials.secretKey` | `cloud` | Key within that Secret (the credentials file). |
| `initContainers` | `[]` | Plugin initContainers; each copies its binary into the shared `plugins` volume. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1000m / mem 512Mi` | Raise for large clusters; backup staging is memory-bound. |
| `metrics.port` | `8085` | Prometheus metrics port (`/metrics`). Doubles as the health probe target. |
| `metrics.service.enabled` | `false` | Create a ClusterIP Service for scraping. |
| `metrics.service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `metrics.service.annotations` | `{}` | e.g. Prometheus scrape annotations. |
| `serviceAccount.create` | `true` | Token automount is on; the server needs its token to reach the API server. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `true` | Install a ClusterRole + ClusterRoleBinding. |
| `rbac.clusterRole.rules` | full access | Cluster-wide by default (see Architecture). Narrow at your own risk. |
| `networkPolicy.enabled` | `false` | Ingress policy allowing only the metrics port. |
| `terminationGracePeriodSeconds` | `3600` | Long grace so an in-flight backup can finish on shutdown. |

Plus the shared `quench-common` knobs: scheduling (nodeSelector, affinity,
tolerations, topology spread), pod and container security contexts, probe
overrides, sidecars, lifecycle hooks, and extra env, volumes, and volume mounts.

## Architecture

The velero server runs as one Deployment replica. It is a controller-runtime
manager: on startup it opens informers against its own CRDs (Backup, Restore,
Schedule, BackupStorageLocation, and the rest), so those CRDs must exist before
the pod starts. That is why they ship in `crds/` rather than as templates. With
no `BackupStorageLocation` present the controllers start and idle, which is how
the server reaches Ready without any cloud access.

Cluster RBAC is not optional for a working install. Velero restores arbitrary
resource types, so it needs to create and patch objects across every API group,
and it reads everything it is asked to back up. `rbac.create` installs a
ClusterRole and ClusterRoleBinding bound to the ServiceAccount. The default rule
set grants full access, which mirrors the cluster-admin binding upstream Velero
uses. You can narrow `rbac.clusterRole.rules`, but a restore of a resource type
your rules do not cover will fail, so scope it to the resource types you actually
back up if you tighten it.

Object-store and volume-snapshot support come from provider plugins, which are
separate images. The convention is an initContainer that copies its plugin
binary into a shared volume the server reads at startup. The chart always creates
that volume, named `plugins`, mounted at `/plugins` in the server. A plugin
initContainer mounts the same volume at `/target`:

```yaml
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.12.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - name: plugins
        mountPath: /target
```

Credentials are referenced by the `BackupStorageLocation` through `spec.credential`,
so Velero mounts only the one Secret key the provider plugin needs rather than
exporting cluster-wide credential env vars. Create the Secret yourself and point
`credentials.existingSecret` at it.

Filesystem-level and CSI volume data movement (backing up the contents of PVCs,
not just their definitions) is handled by the node-agent, a separate DaemonSet
that runs `velero node-agent server` on each node. This chart does not deploy the
node-agent; it installs the control-plane server only. Resource-level backups,
CSI snapshots, and object-store backups all work without it. Add the node-agent
separately if you need pod-volume (filesystem) backups.

Liveness and readiness both `httpGet /metrics` on the metrics port, which answers
200 once the manager is serving. Velero exposes no separate health endpoint, and
`/metrics` coming up is a genuine signal that the process started, so it stands in
for one. There is no application Service: Velero is driven through the API server
and the `velero` CLI, not by receiving requests, so the only optional Service is
for metrics scraping.

## Backing up to S3

A realistic S3 (or S3-compatible, e.g. MinIO) setup. First create the credentials
Secret out of band:

```bash
kubectl -n velero create secret generic velero-cloud \
  --from-file=cloud=./aws-credentials.ini
```

where `aws-credentials.ini` is a standard AWS credentials file:

```ini
[default]
aws_access_key_id=AKIA...
aws_secret_access_key=...
```

Then install the chart with the AWS plugin, the BSL, and that Secret wired in:

```yaml
backupStorageLocation:
  create: true
  name: default
  provider: aws
  bucket: my-cluster-backups
  prefix: prod
  config:
    region: us-east-1
    # For MinIO or another S3-compatible endpoint, also set:
    # s3Url: https://minio.example.com
    # s3ForcePathStyle: "true"

credentials:
  existingSecret: velero-cloud
  secretKey: cloud

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.12.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - name: plugins
        mountPath: /target
```

```bash
helm install velero oci://ghcr.io/quenchworks/charts/velero \
  --namespace velero --create-namespace -f values-s3.yaml
```

Confirm the location goes `Available`, then take a backup:

```bash
kubectl -n velero get backupstoragelocation default
velero --namespace velero backup create demo --include-namespaces default
velero --namespace velero backup describe demo
```

On EKS with IRSA (or GKE workload identity), skip the Secret entirely: leave
`credentials.existingSecret` empty, annotate the ServiceAccount with the IAM role
via `serviceAccount.annotations`, and the plugin picks up the ambient credentials.

## Uninstall

```bash
helm uninstall velero --namespace velero
```

This removes the server, RBAC, and any BSL the chart created. It leaves the CRDs
and every Backup, Restore, and Schedule object in place, since Helm never deletes
CRDs from `crds/`. Your backups in the object store are untouched. To fully remove
Velero, delete the CRDs by hand once you are sure you no longer need those records:

```bash
kubectl get crd -o name | grep velero.io | xargs kubectl delete
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

Keep the plugin version compatible with the server version. The `velero/velero-plugin-for-aws`
tag tracks Velero minor releases, so match it to the app version this chart pins
(`v1.18.x` server pairs with the `v1.12.x` AWS plugin line). The `velero` CLI you
run locally should match the server version too.

`terminationGracePeriodSeconds` defaults to 3600 so an in-flight backup or restore
has time to finish when the pod is asked to shut down. Lower it if your backups are
small and you would rather fail fast on drain.

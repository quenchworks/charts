# Quenchworks quickwit

Hardened [Quickwit](https://quickwit.io/) — a cloud-native search engine for logs
and traces (Rust), with the bundled admin UI — on a minimal, nonroot, 0-CVE image
pinned by digest and cosign-signed (keyless / Sigstore). Runs single node
(standalone) as a StatefulSet on a read-only root filesystem with all
capabilities dropped, serving the REST API and admin UI on port 7280 and gRPC on
7281, and persists its index data and local split cache to a PVC.

## Install

```bash
helm install my-quickwit oci://ghcr.io/quenchworks/charts/quickwit
```

Then port-forward and open the admin UI:

```bash
kubectl port-forward svc/my-quickwit-quickwit 7280:7280
# http://127.0.0.1:7280/ui
```

Size the data volume and pick a storage class:

```bash
helm install my-quickwit oci://ghcr.io/quenchworks/charts/quickwit \
  --set persistence.size=32Gi \
  --set persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/quickwit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/quickwit \
  --owner quenchworks
```

## Values

| Key                                | Default                               | Notes                                                                                     |
| ---------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/quickwit` |                                                                                           |
| `image.digest`                     | (CI-written)                          | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                 | `IfNotPresent`                        | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                     | `""`                                  | Override the chart name in resource names.                                                |
| `replicaCount`                     | `1`                                   | Stateful single node (local storage); do not scale out.                                   |
| `containerPort`                    | `7280`                                | REST API + admin UI port (nonroot, binds 0.0.0.0).                                        |
| `grpcPort`                         | `7281`                                | gRPC port (inter-node / clients).                                                         |
| `service.type`                     | `ClusterIP`                           | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.port`                     | `7280`                                | Service port for the REST/HTTP `http` port.                                               |
| `service.grpcPort`                 | `7281`                                | Service port for the `grpc` port.                                                         |
| `persistence.enabled`              | `true`                                | PVC mounted at `/quickwit/qwdata` (index data + split cache).                             |
| `persistence.size`                 | `8Gi`                                 | Requested volume size.                                                                    |
| `persistence.storageClass`         | `""`                                  | Default class if unset.                                                                   |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                   | PVC access modes.                                                                         |
| `persistence.existingClaim`        | `""`                                  | Bind an existing PVC instead of provisioning one.                                         |
| `resources.requests`               | `100m / 256Mi`                        | CPU / memory requests.                                                                    |
| `resources.limits`                 | `1 / 1Gi`                             | CPU / memory limits.                                                                      |
| `serviceAccount.create`            | `true`                                | Token automount is off.                                                                   |
| `serviceAccount.name`              | `""`                                  | Use an existing ServiceAccount if set.                                                    |
| `rbac.create`                      | `false`                               | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`            | `true`                                | Client ingress from the namespace.                                                        |
| `networkPolicy.allowExternal`      | `false`                               | Set `true` to allow ingress from any source.                                              |
| `podDisruptionBudget.enabled`      | `true`                                |                                                                                           |
| `podDisruptionBudget.minAvailable` | `1`                                   |                                                                                           |
| `ingress.enabled`                  | `false`                               | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`                | `""`                                  | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`              | `{}`                                  | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`              | `null`                                | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`                    | `[]`                                  | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                      | `[]`                                  | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Quickwit runs as a **StatefulSet** so the node keeps a stable network identity and
its own persistent volume. The chart runs `quickwit run` (standalone) with local
file storage. The image ships a baked default config at
`/quickwit/config/quickwit.yaml` (`QW_CONFIG`), so a single node boots with no
extra configuration; `QW_DATA_DIR` and `QW_LISTEN_ADDRESS=0.0.0.0` are set too.
Index data and the local split cache live on a PVC mounted at
`/quickwit/qwdata`, provisioned via a `volumeClaimTemplate`; the container root
filesystem is read-only, with `/tmp` as a writable `emptyDir` for transient
scratch.

Two ports are exposed: **REST + admin UI (7280)** and **gRPC (7281)**; the
ClusterIP Service maps both. Quickwit serves `/health/livez` (liveness, process
up) and `/health/readyz` (readiness, cluster ready to serve); index init can take
a moment, so the liveness probe uses a generous initial delay.

Single node only: with local file storage the index state is not shared, so the
workload is not horizontally scalable. Keep `replicaCount` at 1.

## Configuration examples

For HA or a distributed cluster, front Quickwit with object storage
(S3/GCS/Azure) and a shared metastore via `extraEnvVars`:

```yaml
extraEnvVars:
  - name: QW_METASTORE_URI
    value: s3://my-bucket/quickwit-metastore
  - name: QW_DEFAULT_INDEX_ROOT_URI
    value: s3://my-bucket/quickwit-indexes
```

## Uninstall

```bash
helm uninstall my-quickwit
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the index data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-quickwit
```

## Notes

Single node only: this chart runs `quickwit run` (standalone) with local file
storage, so index data lives on the node's PVC and cannot be horizontally scaled.
For HA or a distributed cluster, front it with object storage (S3/GCS/Azure) and
a shared metastore. The chart depends on the `quench-common` library chart,
pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. The container runs
nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped,
and the image is pinned by digest.

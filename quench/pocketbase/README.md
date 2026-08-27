# Quenchworks PocketBase

Hardened [PocketBase](https://pocketbase.io/) — an open-source backend in a
single Go binary: an embedded SQLite database, authentication, file storage, a
realtime REST API, and a web admin UI. It runs as a single-node StatefulSet,
binds HTTP on container port 8080, and persists its SQLite database and uploaded
files to a PVC at `/pb_data`. The image is minimal, runs nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, ships 0-CVE, is
cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install my-pocketbase oci://ghcr.io/quenchworks/charts/pocketbase
```

Size the data volume and pick a storage class:

```bash
helm install my-pocketbase oci://ghcr.io/quenchworks/charts/pocketbase \
  --set persistence.size=10Gi \
  --set persistence.storageClass=fast-ssd
```

Then port-forward and open the admin dashboard (create the initial superuser on
first visit):

```bash
kubectl port-forward svc/my-pocketbase-pocketbase 8090:80
# http://127.0.0.1:8090/_/
```

Or create the first superuser non-interactively with a one-off exec:

```bash
kubectl exec statefulset/my-pocketbase-pocketbase -- \
  pocketbase superuser upsert admin@example.com <password> --dir /pb_data
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pocketbase \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/pocketbase \
  --owner quenchworks
```

## Values

| Key                                | Default                                 | Notes                                                                                                              |
| ---------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `image.repository`                 | `ghcr.io/quenchworks/images/pocketbase` |                                                                                                                    |
| `image.digest`                     | (CI-written)                            | Required. Charts pin by digest, never a tag.                                                                       |
| `image.pullPolicy`                 | `IfNotPresent`                          | `Always`, `IfNotPresent`, or `Never`.                                                                              |
| `nameOverride`                     | `""`                                    | Override the chart name in resource names.                                                                         |
| `replicaCount`                     | `1`                                     | Stateful single node (SQLite). Schema pins this to 1; do not scale out.                                            |
| `containerPort`                    | `8080`                                  | Port PocketBase binds, baked into the image entrypoint. Drives the container port, Service targetPort, and probes. |
| `persistence.enabled`              | `true`                                  | 1Gi PVC mounted at `/pb_data` (DB + uploaded files + migrations + backups).                                        |
| `persistence.size`                 | `1Gi`                                   | Requested volume size.                                                                                             |
| `persistence.storageClass`         | `""`                                    | Default class if unset.                                                                                            |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                     | PVC access modes.                                                                                                  |
| `persistence.annotations`          | `{}`                                    | Annotations on the PVC template.                                                                                   |
| `persistence.selector`             | `{}`                                    | Bind to a matching PV by selector.                                                                                 |
| `persistence.existingClaim`        | `""`                                    | Bind an existing PVC instead of provisioning one.                                                                  |
| `resources.requests`               | `cpu 50m / mem 64Mi`                    | CPU / memory requests.                                                                                             |
| `resources.limits`                 | `cpu 500m / mem 256Mi`                  | CPU / memory limits.                                                                                               |
| `service.type`                     | `ClusterIP`                             | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                                        |
| `service.port`                     | `80`                                    | Service port, forwards to the container's `http` port (8080).                                                      |
| `serviceAccount.create`            | `true`                                  | Token automount is off.                                                                                            |
| `serviceAccount.name`              | `""`                                    | Use an existing ServiceAccount if set.                                                                             |
| `serviceAccount.annotations`       | `{}`                                    | Annotations on the ServiceAccount.                                                                                 |
| `rbac.create`                      | `false`                                 | Minimal Role/RoleBinding.                                                                                          |
| `networkPolicy.enabled`            | `true`                                  | Restricts client ingress to the release namespace.                                                                 |
| `networkPolicy.allowExternal`      | `false`                                 | Set `true` to allow ingress from any source.                                                                       |
| `podDisruptionBudget.enabled`      | `true`                                  |                                                                                                                    |
| `podDisruptionBudget.minAvailable` | `1`                                     |                                                                                                                    |
| `ingress.enabled`                  | `false`                                 | Create an Ingress for this chart. HTTP only.                                                                       |
| `ingress.className`                | `""`                                    | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                                   |
| `ingress.annotations`              | `{}`                                    | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                                     |
| `ingress.servicePort`              | `null`                                  | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.                                 |
| `ingress.hosts`                    | `[]`                                    | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.                          |
| `ingress.tls`                      | `[]`                                    | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.                               |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `customLivenessProbe`/`customReadinessProbe`/
`customStartupProbe`).

## Architecture

PocketBase runs as a **StatefulSet** so the node keeps a stable identity and its
own persistent volume. Everything it owns — the SQLite database, uploaded files,
migrations, and backups — lives under a single directory. State is a single
volume mounted at `/pb_data`, provisioned as one PVC via a `volumeClaimTemplate`;
with `persistence.enabled=false` it falls back to an `emptyDir` and does not
survive a restart.

The image's entrypoint is baked as
`pocketbase serve --http 0.0.0.0:8080 --dir /pb_data`, so the bind port is fixed
at **8080**. `containerPort` only drives the container port declaration, the
Service `targetPort`, and the probes — leave it at 8080 to match the baked
`--http` flag. The Service exposes port **80** and forwards to the container's
`http` port. Liveness and readiness both `httpGet /api/health`, which returns
`{"code":200,"message":"API is healthy.",...}` once the server is up.

The container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped. Only two paths are writable: the `/pb_data` PVC and an
in-memory `/tmp` for upload scratch.

Single node is the only supported topology. PocketBase stores everything in a
local SQLite database plus a directory of uploaded files, so it cannot be
horizontally scaled — the schema pins `replicaCount` to 1.

## Configuration examples

Single node with a larger volume on a named storage class:

```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: fast-ssd
```

Expose the API to clients outside the release namespace (browsers, apps, SDKs
usually reach PocketBase from outside the cluster):

```yaml
networkPolicy:
  enabled: true
  allowExternal: true
```

PocketBase has no built-in bootstrap env for the first superuser. Create it from
the admin UI on first visit, or run `pocketbase superuser upsert` via a one-off
exec (see Install). To pass your own environment to the process, use
`extraEnvVars` / `extraEnvVarsSecret` and wire it through `command`/`args`.

## Uninstall

```bash
helm uninstall my-pocketbase
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-pocketbase
```

## Notes

Single node only, by design: the local SQLite database plus on-disk uploads
cannot be shared across replicas, and the schema enforces `replicaCount: 1`.
Back up by snapshotting the `/pb_data` PVC or using PocketBase's own backup
feature. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

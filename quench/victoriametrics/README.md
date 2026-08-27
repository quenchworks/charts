# Quenchworks VictoriaMetrics

Hardened [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics) —
a fast, cost-efficient single-node time-series database that speaks PromQL and
Prometheus `remote_write` — on a minimal, nonroot, 0-CVE image pinned by digest.
A single self-contained Go binary exposes a Prometheus-compatible HTTP API on
port 8428, running on a read-only root filesystem with all capabilities dropped.
The image is cosign-signed (keyless / Sigstore) and the chart pins it by the
signed digest, never a tag.

## Install

```bash
helm install vm oci://ghcr.io/quenchworks/charts/victoriametrics
```

Size the data volume and pick a storage class:

```bash
helm install vm oci://ghcr.io/quenchworks/charts/victoriametrics \
  --set persistence.size=64Gi \
  --set persistence.storageClass=fast-ssd
```

Point Prometheus `remote_write` at the service, or import samples directly:

```yaml
remote_write:
  - url: http://vm-victoriametrics:8428/api/v1/write
```

```bash
# instant query
curl 'http://vm-victoriametrics:8428/api/v1/query?query=quench_metric'
# range query (use this to read back a just-written point, which can fall
# outside the instant query's staleness window)
curl 'http://vm-victoriametrics:8428/api/v1/query_range?query=quench_metric&start=-5m&step=30s'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/victoriametrics \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/victoriametrics \
  --owner quenchworks
```

## Values

| Key                                | Default                                      | Notes                                                                                               |
| ---------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/victoriametrics` |                                                                                                     |
| `image.digest`                     | (CI-written)                                 | Required. Charts pin by digest, never a tag.                                                        |
| `image.pullPolicy`                 | `IfNotPresent`                               | `Always`, `IfNotPresent`, or `Never`.                                                               |
| `nameOverride`                     | `""`                                         | Override the chart name in resource names.                                                          |
| `replicaCount`                     | `1`                                          | Single node; the clustered topology is a follow-up.                                                 |
| `config.retentionPeriod`           | `"1"`                                        | Rendered as `-retentionPeriod`. VM duration shorthand (`1` = 1 month; also `12`, `1d`, `1w`, `1y`). |
| `config.extraArgs`                 | `[]`                                         | Raw flags appended verbatim to the server (e.g. `-dedup.minScrapeInterval=30s`).                    |
| `persistence.enabled`              | `true`                                       | PVC mounted at `/storage`. When `false`, uses an `emptyDir` (data is lost on restart).              |
| `persistence.size`                 | `16Gi`                                       | Requested volume size.                                                                              |
| `persistence.storageClass`         | `""`                                         | Default class if unset.                                                                             |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                          | PVC access modes.                                                                                   |
| `persistence.annotations`          | `{}`                                         | Annotations on the PVC template.                                                                    |
| `persistence.selector`             | `{}`                                         | Bind to a matching PV by selector.                                                                  |
| `persistence.existingClaim`        | `""`                                         | Bind an existing PVC instead of provisioning one.                                                   |
| `service.type`                     | `ClusterIP`                                  | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                         |
| `service.port`                     | `8428`                                       | The single HTTP API port (read / write / query).                                                    |
| `resources.requests`               | `250m / 256Mi`                               | CPU / memory requests.                                                                              |
| `resources.limits`                 | `1 / 1Gi`                                    | CPU / memory limits.                                                                                |
| `command`                          | `[]`                                         | Override the entrypoint.                                                                            |
| `serviceAccount.create`            | `true`                                       | Token automount is off.                                                                             |
| `serviceAccount.name`              | `""`                                         | Use an existing ServiceAccount if set.                                                              |
| `serviceAccount.annotations`       | `{}`                                         | Annotations on the ServiceAccount.                                                                  |
| `rbac.create`                      | `false`                                      | Minimal Role/RoleBinding.                                                                           |
| `networkPolicy.enabled`            | `true`                                       | Restricts HTTP ingress to the release namespace.                                                    |
| `networkPolicy.allowExternal`      | `false`                                      | Set `true` to allow ingress from any source.                                                        |
| `podDisruptionBudget.enabled`      | `true`                                       |                                                                                                     |
| `podDisruptionBudget.minAvailable` | `1`                                          |                                                                                                     |
| `ingress.enabled`                  | `false`                                      | Create an Ingress for this chart. HTTP only.                                                        |
| `ingress.className`                | `""`                                         | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                    |
| `ingress.annotations`              | `{}`                                         | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                      |
| `ingress.servicePort`              | `null`                                       | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.                  |
| `ingress.hosts`                    | `[]`                                         | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.           |
| `ingress.tls`                      | `[]`                                         | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.                |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

VictoriaMetrics runs as a **StatefulSet** so the TSDB keeps a stable identity and
its own persistent volume. The container exposes a single Prometheus-compatible
HTTP API on port **8428** — ingestion (`/api/v1/write`, `/api/v1/import/...`),
query (`/api/v1/query`, `/api/v1/query_range`) and management all share it. The
entrypoint pins `-storageDataPath` to `VM_STORAGE` (`/storage`, the PVC mount)
and `-httpListenAddr` to `VM_HTTP_LISTEN` (`:8428`); `config.retentionPeriod` and
`config.extraArgs` pass through as container args. Both liveness and readiness
probe `GET /health`, which returns plain `OK` once the server is up.

State lives on the writable `/storage` PVC (a `volumeClaimTemplate`, or
`persistence.existingClaim`); with `persistence.enabled=false` it falls back to
an `emptyDir` that does not survive a restart.

## Configuration examples

Twelve-month retention on a larger volume, with sample de-duplication:

```yaml
persistence:
  enabled: true
  size: 64Gi
  storageClass: fast-ssd
config:
  retentionPeriod: "12"
  extraArgs:
    - -dedup.minScrapeInterval=30s
```

Bind an existing volume and raise limits for a busier ingest rate:

```yaml
persistence:
  existingClaim: vm-data
resources:
  requests: { cpu: 500m, memory: 512Mi }
  limits: { cpu: "2", memory: 4Gi }
```

## Uninstall

```bash
helm uninstall vm
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the samples gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=vm
```

## Notes

Single node. The clustered topology (`vminsert` / `vmselect` / `vmstorage`) is a
tracked follow-up. VictoriaMetrics has **no built-in authentication** — there is
no Secret to manage. The NetworkPolicy is the trust boundary; keep it enabled,
and front the service with an authenticating proxy if you must expose it beyond
the cluster. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
(uid 1001) on a read-only root filesystem with all capabilities dropped, and the
image is pinned by digest.

# Quenchworks VictoriaLogs

Hardened [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/) — a fast,
single-binary log database with an HTTP ingestion and query API — on a minimal,
nonroot, 0-CVE image pinned by digest. It serves the HTTP API on port 9428 and
persists all log data to a PVC, running on a read-only root filesystem with all
capabilities dropped. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

```bash
helm install my-victorialogs oci://ghcr.io/quenchworks/charts/victorialogs
```

Size the data volume and pick a storage class:

```bash
helm install my-victorialogs oci://ghcr.io/quenchworks/charts/victorialogs \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd
```

Then port-forward and open the built-in query UI:

```bash
kubectl port-forward svc/my-victorialogs-victorialogs 9428:9428
# http://127.0.0.1:9428/select/vmui
```

Ingest one JSON log line and read it back with LogsQL:

```bash
echo '{"_msg":"hello from quench","level":"info"}' | \
  curl -X POST -H 'Content-Type: application/stream+json' --data-binary @- \
  'http://127.0.0.1:9428/insert/jsonline?_stream_fields=level'

curl 'http://127.0.0.1:9428/select/logsql/query' --data-urlencode 'query=*'
```

VictoriaLogs speaks the Elasticsearch bulk, Loki push, OpenTelemetry, journald,
syslog and native JSON ingestion APIs, so most existing log shippers (Vector,
Fluent Bit, Promtail, Filebeat, ...) can write to it directly.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/victorialogs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/victorialogs \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/victorialogs` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node; schema caps this at 1. VictoriaLogs is not scaled by adding replicas. |
| `containerPort` | `9428` | HTTP listen port, wired to `-httpListenAddr` via `VL_HTTP_LISTEN`. |
| `storagePath` | `/victoria-logs-data` | Data dir (`-storageDataPath` via `VL_STORAGE`); the PVC mount point. |
| `persistence.enabled` | `true` | PVC mounted at `storagePath`. When `false`, uses an `emptyDir` (data is lost on restart). |
| `persistence.size` | `10Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `9428` | Service port for ingestion and queries. |
| `resources.requests` | `100m / 128Mi` | CPU / memory requests. |
| `resources.limits` | `1 / 1Gi` | CPU / memory limits. |
| `args` | `[]` | Extra flags appended to `victoria-logs` (e.g. `-retentionPeriod=30d`). |
| `command` | `[]` | Override the entrypoint. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source (log shippers, query clients). |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

VictoriaLogs runs as a **StatefulSet** so the log store keeps a stable identity
and its own persistent volume. The container serves the HTTP API on port
**9428**; the entrypoint maps `containerPort` and `storagePath` onto
`-httpListenAddr` and `-storageDataPath` (via the `VL_HTTP_LISTEN` and
`VL_STORAGE` env vars), keeping the storage mount, bind port and probes in sync.
Both liveness and readiness probe `GET /health`, which returns `200 OK` once the
server is up.

State lives on one volume mounted at `storagePath`, backed by the PVC (a
`volumeClaimTemplate`, or `persistence.existingClaim`); with
`persistence.enabled=false` it falls back to an `emptyDir` that does not survive
a restart. VictoriaLogs is a single-node database — each pod would own its own
disjoint dataset, so `replicaCount` is capped at 1 by the schema.

## Configuration examples

Larger retention window and volume on a named storage class:

```yaml
persistence:
  enabled: true
  size: 50Gi
  storageClass: fast-ssd
args:
  - -retentionPeriod=30d
```

Point a Vector sink at the service (Elasticsearch bulk API):

```yaml
# in your Vector config
sinks:
  victorialogs:
    type: elasticsearch
    inputs: ["my_source"]
    endpoints: ["http://my-victorialogs-victorialogs:9428/insert/elasticsearch"]
    mode: bulk
```

## Uninstall

```bash
helm uninstall my-victorialogs
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the log data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-victorialogs
```

## Notes

Single node by design; scale retention with the PVC and `-retentionPeriod`, not
replicas. VictoriaLogs serves its API without built-in authentication — keep the
NetworkPolicy as the trust boundary and front it with an authenticating proxy
before exposing it beyond the cluster. The chart depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.
Every container runs as nonroot (uid 1001) on a read-only root filesystem with
all capabilities dropped, and the image is pinned by digest.

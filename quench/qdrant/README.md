# Quenchworks Qdrant

Hardened [Qdrant](https://github.com/qdrant/qdrant), a high-performance vector
database and similarity-search engine for AI embeddings, on a minimal, nonroot,
0-CVE image pinned by digest and cosign-signed (keyless / Sigstore). Runs
single-node as a StatefulSet, serving the REST API and web dashboard on port
6333 and gRPC on port 6334, on a read-only root filesystem with all capabilities
dropped. Qdrant ships with no auth by default, so the NetworkPolicy is the trust
boundary; optional API-key auth locks down the data path.

## Install

```bash
helm install my-qdrant oci://ghcr.io/quenchworks/charts/qdrant
```

Size the data volume and pick a storage class:

```bash
helm install my-qdrant oci://ghcr.io/quenchworks/charts/qdrant \
  --set persistence.size=32Gi \
  --set persistence.storageClass=fast-ssd
```

Require an API key on the REST and gRPC data paths:

```bash
helm install my-qdrant oci://ghcr.io/quenchworks/charts/qdrant \
  --set auth.apiKey=a-strong-secret
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/qdrant \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/qdrant \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/qdrant` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node; keep at 1 (see Architecture). |
| `auth.apiKey` | `""` | API key; empty disables auth. Wired to `QDRANT__SERVICE__API_KEY` via a Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the key instead. |
| `auth.existingSecretKey` | `api-key` | Key within `existingSecret`. |
| `config.enabled` | `false` | Mount an advanced `production.yaml`. |
| `config.data` | `log_level: INFO` | Templated config YAML (rendered via `tpl`). |
| `extraArgs` | `[]` | Extra flags appended to the qdrant binary. |
| `persistence.enabled` | `true` | Provision a PVC for `/qdrant/storage`. `false` uses an `emptyDir` (testing only). |
| `persistence.size` | `16Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `6333` | REST API + dashboard port. |
| `service.grpcPort` | `6334` | gRPC port. |
| `resources.requests` | `250m / 256Mi` | CPU / memory requests. |
| `resources.limits` | `1 / 1Gi` | CPU / memory limits. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to 6333/6334 in the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `podSecurityContext`, `containerSecurityContext`,
and the probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Qdrant runs as a **StatefulSet** so the node keeps a stable network identity and
its own persistent volume. Two ports are exposed: **REST + dashboard (6333)** and
**gRPC (6334)**. The Service is a ClusterIP mapping both. State lives on local
disk: the chart mounts a writable volume at `/qdrant/storage` (with snapshots
under `/qdrant/snapshots`) and runs on a read-only root filesystem, with `/tmp`
as a writable `emptyDir` scratch. `persistence.enabled=true` provisions one PVC
via a `volumeClaimTemplate`; with `persistence.enabled=false` the storage dir is
an `emptyDir` and does not survive a restart.

Health endpoints `/healthz`, `/livez`, and `/readyz` (on 6333) always return 200
and stay unauthenticated even when an API key is set, so the liveness (`/livez`)
and readiness (`/readyz`) probes keep working regardless of auth.

The default topology is **single-node** (`replicaCount: 1`, local storage), which
handles a large range of workloads and scales vertically. Qdrant also supports a
**distributed** mode (a Raft-coordinated cluster of peers with sharded and
replicated collections), but that needs coordinated peer bootstrap and a shared
topology and is a tracked follow-up. Keep `replicaCount` at 1 here.

## Configuration examples

Port-forward and drive the REST API — create a collection, upsert a point, then
search:

```sh
kubectl port-forward svc/my-qdrant 6333:6333
# open http://127.0.0.1:6333/dashboard

# create a 4-dim collection
curl -fsS -X PUT http://127.0.0.1:6333/collections/demo \
  -H 'content-type: application/json' \
  -d '{"vectors":{"size":4,"distance":"Dot"}}'

# upsert a point (wait=true makes it immediately searchable)
curl -fsS -X PUT 'http://127.0.0.1:6333/collections/demo/points?wait=true' \
  -H 'content-type: application/json' \
  -d '{"points":[{"id":1,"vector":[0.1,0.2,0.3,0.4],"payload":{"label":"a"}}]}'

# search
curl -fsS -X POST http://127.0.0.1:6333/collections/demo/points/search \
  -H 'content-type: application/json' \
  -d '{"vector":[0.1,0.2,0.3,0.4],"limit":1,"with_payload":true}'
```

Require an API key, or reference your own Secret:

```yaml
auth:
  apiKey: "a-strong-secret"      # renders a Secret -> QDRANT__SERVICE__API_KEY
```

```yaml
auth:
  existingSecret: my-qdrant-secret
  existingSecretKey: api-key
```

Send the key as the `api-key` header on every REST/gRPC request:

```sh
curl -H "api-key: a-strong-secret" http://127.0.0.1:6333/collections
```

Simple toggles are best set as `QDRANT__...` env vars via `extraEnvVars`. For
anything env vars cannot express, enable a mounted config, rendered to a
ConfigMap at `/qdrant/config/production.yaml` and layered on with an extra
`--config-path` flag (Qdrant merges configs; later wins). The block is templated,
so Helm values render inside it, and the pod rolls on its checksum:

```yaml
config:
  enabled: true
  data: |
    log_level: INFO
    storage:
      performance:
        max_search_threads: 4
```

## Uninstall

```bash
helm uninstall my-qdrant
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-qdrant
```

## Notes

Single node for now; a distributed, Raft-coordinated topology with sharded and
replicated collections is a tracked follow-up. The chart depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
(uid/gid 1001) on a read-only root filesystem with all capabilities dropped,
`allowPrivilegeEscalation: false` and `seccompProfile: RuntimeDefault`; the
ServiceAccount token is not auto-mounted and the image is pinned by digest.
Qdrant serves with no auth by default — set `auth.apiKey` (or `auth.existingSecret`)
and keep the NetworkPolicy as the trust boundary before exposing it beyond the
cluster.

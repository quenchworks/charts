# Qdrant (Quenchworks)

Quenchworks-hardened [Qdrant](https://github.com/qdrant/qdrant) — a high-performance
vector database and similarity-search engine. Runs from a minimal, nonroot, 0-CVE
image pinned by digest and cosign-signed. Single-node by default, with optional
API-key auth; the NetworkPolicy is the trust boundary.

- **App version:** 1.18.2 (Apache-2.0)
- **Image:** `ghcr.io/quenchworks/images/qdrant` (multi-arch amd64+arm64, pinned by digest)
- **Topology:** StatefulSet, one replica (single node). Distributed/clustered mode is a tracked follow-up.

## TL;DR

```sh
helm install my-qdrant oci://ghcr.io/quenchworks/charts/qdrant
```

## What it serves

| Port | Name   | Protocol | Purpose                                   |
|------|--------|----------|-------------------------------------------|
| 6333 | `http` | TCP      | REST API + web dashboard at `/dashboard`  |
| 6334 | `grpc` | TCP      | gRPC API                                  |

Health endpoints `/healthz`, `/livez`, `/readyz` (on 6333) always return 200 and are
**unauthenticated** even when an API key is set, so the liveness (`/livez`) and
readiness (`/readyz`) probes keep working regardless of auth.

## Storage

Qdrant keeps index + payload state on local disk. The chart mounts a writable
volume at `/qdrant/storage` (with snapshots under `/qdrant/snapshots`) and runs on a
read-only root filesystem. `persistence.enabled=true` (default) provisions a PVC via
a `volumeClaimTemplate`; set `persistence.existingClaim` to reuse a PVC, or
`persistence.enabled=false` for an ephemeral `emptyDir` (testing only). `/tmp` is a
writable `emptyDir` scratch.

## Connecting

REST + dashboard and gRPC are exposed by a ClusterIP `Service`. From inside the cluster:

```
REST + dashboard : http://<release>-qdrant.<namespace>.svc.cluster.local:6333
gRPC             : <release>-qdrant.<namespace>.svc.cluster.local:6334
```

Port-forward to reach it from your workstation and open the dashboard:

```sh
kubectl port-forward svc/<release>-qdrant 6333:6333
# open http://127.0.0.1:6333/dashboard
```

### Create a collection, upsert a point, search

```sh
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

## API-key authentication

Qdrant ships with no auth by default — inside a cluster the NetworkPolicy is the
boundary. To require an API key on the data path:

```yaml
auth:
  apiKey: "a-strong-secret"      # chart renders a Secret -> QDRANT__SERVICE__API_KEY
```

or reference your own Secret:

```yaml
auth:
  existingSecret: my-qdrant-secret
  existingSecretKey: api-key
```

Send the key as the `api-key` header on every REST/gRPC request:

```sh
curl -H "api-key: a-strong-secret" http://127.0.0.1:6333/collections
```

Health endpoints stay open, so probes are unaffected.

## Advanced config

Simple toggles are best set as `QDRANT__...` env vars via `extraEnvVars`. For anything
env vars cannot express, enable a mounted config:

```yaml
config:
  enabled: true
  data: |
    log_level: INFO
    storage:
      performance:
        max_search_threads: 4
```

It is rendered to a ConfigMap mounted at `/qdrant/config/production.yaml` and layered
on with an extra `--config-path` flag (Qdrant merges configs; later wins). The block
is templated, so Helm values render inside it, and the pod rolls on its checksum.

## Single-node vs distributed

This chart runs Qdrant as a **single node** (one StatefulSet replica, local storage).
That handles a large range of workloads and scales vertically. Qdrant also supports a
**distributed** mode — a Raft-coordinated cluster of peers with sharded and replicated
collections — which needs coordinated peer bootstrap and a shared topology. That is a
tracked follow-up; keep `replicaCount` at `1` here.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/qdrant` | Image repo (digest-pinned) |
| `image.digest` | `sha256:2643748a…` | CI-maintained digest. Never a tag |
| `replicaCount` | `1` | Single node; keep at 1 |
| `auth.apiKey` | `""` | API key; empty disables auth |
| `auth.existingSecret` | `""` | Use an existing Secret for the key |
| `auth.existingSecretKey` | `api-key` | Key within `existingSecret` |
| `config.enabled` | `false` | Mount an advanced `production.yaml` |
| `config.data` | `log_level: INFO` | Templated config YAML |
| `extraArgs` | `[]` | Extra flags appended to the qdrant binary |
| `persistence.enabled` | `true` | Provision a PVC for `/qdrant/storage` |
| `persistence.size` | `16Gi` | PVC size |
| `persistence.existingClaim` | `""` | Reuse an existing PVC |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `6333` | REST + dashboard port |
| `service.grpcPort` | `6334` | gRPC port |
| `resources` | requests 250m/256Mi, limits 1/1Gi | Container resources |
| `networkPolicy.enabled` | `true` | Restrict ingress to 6333/6334 |
| `networkPolicy.allowExternal` | `false` | Allow ingress from any pod |
| `podDisruptionBudget.enabled` | `true` | PDB (`minAvailable: 1`) |
| `serviceAccount.create` | `true` | Create a ServiceAccount |

Plus the standard quench-common knobs: `podLabels`, `podAnnotations`, `nodeSelector`,
`affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`,
`extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`, `lifecycleHooks`, `command`,
`podSecurityContext`, `containerSecurityContext`, and probe overrides.

## Security

- Runs as nonroot uid/gid 1001, read-only root filesystem, all capabilities dropped,
  `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault`.
- ServiceAccount token is not auto-mounted.
- Image pinned by digest and cosign-signed (keyless / Sigstore).

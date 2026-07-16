# Quenchworks Thanos

Hardened [Thanos](https://github.com/thanos-io/thanos) on a minimal, nonroot,
0-CVE image, built from source, cosign-signed (keyless / Sigstore) and pinned by
digest.

Thanos is a single static Go binary that runs every component via a subcommand
(`query`, `receive`, `store`, `compact`, `rule`, `sidecar`). This chart deploys
each component as a separate, individually toggleable workload from that one
image. By default it ships a **self-contained query + receive pair** that needs
no object storage, so it installs and reaches Ready on a fresh cluster.

## Install

```sh
helm install metrics oci://ghcr.io/quenchworks/charts/thanos
```

Two workloads come up:

- **query** (Deployment) — the user-facing PromQL UI/API on HTTP `10902`, Store
  API on gRPC `10901`. It fans out to every Store API endpoint.
- **receive** (StatefulSet) — a remote-write target (`19291`) with a **local
  TSDB** on a PVC and its own Store API on gRPC `10901`.

query discovers receive's Store API through receive's headless Service via DNS
SRV (`dnssrv+_grpc._tcp.<release>-thanos-receive-headless...`), so query only
goes Ready once it has connected to receive.

```sh
kubectl port-forward svc/metrics-thanos-query 10902:10902
curl http://127.0.0.1:10902/-/healthy
curl http://127.0.0.1:10902/-/ready
curl 'http://127.0.0.1:10902/api/v1/query?query=up'
```

Point Prometheus remote_write at receive:

```yaml
remote_write:
  - url: http://metrics-thanos-receive.<ns>.svc.cluster.local:19291/api/v1/receive
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/thanos \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/thanos --owner quenchworks`.

## Values

The `image` and the security/scheduling knobs are shared across every component;
each component (`query`, `receive`, `store`, `compact`, `rule`, `sidecar`) has
its own block.

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/thanos` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `objstoreConfig.yaml` | `""` | Inline objstore config, written to a Secret and passed via `--objstore.config-file`. |
| `objstoreConfig.existingSecret` | `""` | Externally-managed objstore Secret (key `objstore.yml`). |
| `query.enabled` | `true` | PromQL UI/API entry point (Deployment). |
| `query.replicaCount` | `1` | Stateless. |
| `query.stores` | `[]` | Static stores to also query (each becomes `--endpoint`). |
| `query.extraEndpoints` | `[]` | Extra `--endpoint`/`--endpoint-group` targets. |
| `query.extraArgs` | `[]` | Extra flags. |
| `query.service.httpPort` | `10902` | PromQL UI/API. |
| `query.service.grpcPort` | `10901` | Store API. |
| `query.podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `receive.enabled` | `true` | Local-TSDB remote-write target (StatefulSet). |
| `receive.replicaCount` | `1` | |
| `receive.replicaLabel` | `"0"` | Value written into ingested series. |
| `receive.retention` | `15d` | Local TSDB retention. |
| `receive.persistence.enabled` | `true` | Writable PVC at `/var/thanos/receive`. |
| `receive.persistence.size` | `8Gi` | |
| `receive.persistence.storageClass` | `""` | Default class if unset. |
| `receive.persistence.accessModes` | `["ReadWriteOnce"]` | |
| `receive.objstore.enabled` | `false` | Also upload blocks to object storage (needs `objstoreConfig`). |
| `receive.service.remoteWritePort` | `19291` | Prometheus remote-write receiver. |
| `store.enabled` | `false` | Store Gateway over object storage (needs `objstoreConfig`). |
| `store.persistence.size` | `8Gi` | Local index/chunk cache at `/var/thanos/store`. |
| `compact.enabled` | `false` | Single-replica compactor (needs `objstoreConfig`). |
| `compact.persistence.size` | `8Gi` | Working dir at `/var/thanos/compact`. |
| `rule.enabled` | `false` | Rule evaluation + alerting (StatefulSet). |
| `rule.ruleFiles` | `{}` | Inline rule files (filename -> rule YAML). |
| `rule.alertmanagers` | `[]` | Alertmanager URLs. |
| `rule.persistence.size` | `8Gi` | TSDB at `/var/thanos/rule`. |
| `sidecar.enabled` | `false` | Not deployed by this chart; runs inside Prometheus. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | query UI/API is user-facing; set `false` to restrict to the namespace. |

Each component also takes `resources` (requests/limits). Plus the shared
`quench-common` knobs across every workload: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Components

| Component | Default | Workload | Needs object storage |
|-----------|---------|----------|----------------------|
| `query`   | **on**  | Deployment  | no |
| `receive` | **on**  | StatefulSet | no (local TSDB) |
| `store`   | off     | StatefulSet | **yes** |
| `compact` | off     | Deployment (1 replica) | **yes** |
| `rule`    | off     | StatefulSet | optional |
| `sidecar` | off     | not deployed (runs inside Prometheus) | — |

Each component has its own block in `values.yaml` (`enabled`, `replicaCount`,
`resources`, `persistence`, `service`). The `image` and the security/scheduling
knobs are shared.

## Object storage

`store`, `compact` (and `receive`/`rule` when their objstore flag is on) read a
single objstore config. Set `objstoreConfig.yaml` to a Thanos objstore config
and it is written to a Secret and passed via `--objstore.config-file`; or point
`objstoreConfig.existingSecret` at an externally-managed Secret (key
`objstore.yml`). Enabling `store.enabled`/`compact.enabled` without an objstore
config fails the render with a clear message.

```yaml
objstoreConfig:
  yaml: |
    type: S3
    config:
      bucket: thanos
      endpoint: minio.storage.svc:9000
      access_key: ...
      secret_key: ...
      insecure: true
store:
  enabled: true
compact:
  enabled: true
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/thanos` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `query.enabled` | `true` | PromQL UI/API entry point |
| `query.replicaCount` | `1` | stateless Deployment |
| `query.stores` / `query.extraEndpoints` | `[]` | extra `--endpoint` targets |
| `receive.enabled` | `true` | local-TSDB remote-write target |
| `receive.persistence.size` | `8Gi` | TSDB PVC at `/var/thanos/receive` |
| `receive.retention` | `15d` | local TSDB retention |
| `store.enabled` | `false` | Store Gateway (needs `objstoreConfig`) |
| `compact.enabled` | `false` | single-replica compactor (needs `objstoreConfig`) |
| `rule.enabled` | `false` | rule evaluation + alerting |
| `objstoreConfig.yaml` | `""` | inline objstore config (written to a Secret) |
| `objstoreConfig.existingSecret` | `""` | external objstore Secret (key `objstore.yml`) |
| `networkPolicy.allowExternal` | `true` | query UI/API is user-facing |

Runs nonroot (uid/gid 1001) with a read-only rootfs. receive/store/rule get a
writable PVC for their TSDB; compact a working-dir PVC; query a writable `/tmp`.

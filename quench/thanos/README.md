# Quenchworks Thanos

Hardened [Thanos](https://github.com/thanos-io/thanos) on a minimal, nonroot,
0-CVE image, built from source and pinned by digest.

Thanos is a single static Go binary that runs every component via a subcommand
(`query`, `receive`, `store`, `compact`, `rule`, `sidecar`). This chart deploys
each component as a separate, individually toggleable workload from that one
image. By default it ships a **self-contained query + receive pair** that needs
no object storage, so it installs and reaches Ready out of the box.

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

# Quenchworks victorialogs

Hardened [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/) — a fast,
single-binary log database — on a minimal, nonroot, 0-CVE image pinned by digest.
Single node; persists all log data to a PVC.

## Install

```bash
helm install my-victorialogs oci://ghcr.io/quenchworks/charts/victorialogs
```

Then port-forward and open the built-in query UI:

```bash
kubectl port-forward svc/my-victorialogs-victorialogs 9428:9428
# http://127.0.0.1:9428/select/vmui
```

## Ingest and query

```bash
# ingest one JSON log line
echo '{"_msg":"hello from quench","level":"info"}' | \
  curl -X POST -H 'Content-Type: application/stream+json' --data-binary @- \
  'http://127.0.0.1:9428/insert/jsonline?_stream_fields=level'

# query with LogsQL
curl 'http://127.0.0.1:9428/select/logsql/query' --data-urlencode 'query=*'
```

VictoriaLogs speaks Elasticsearch bulk, Loki push, OpenTelemetry, journald,
syslog and its native JSON ingestion APIs, so most existing log shippers
(Vector, Fluent Bit, Promtail, Filebeat, ...) can write to it directly.

## Persistence

Log data lives on a PVC mounted at `storagePath` (default `/victoria-logs-data`,
passed to VictoriaLogs as `-storageDataPath`). Tune `persistence.size` and
`persistence.storageClass` for your retention needs, and set
`args: ["-retentionPeriod=30d"]` to cap how long logs are kept.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/victorialogs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/victorialogs` | Image, pinned by digest (never a tag). |
| `image.digest` | `sha256:c96cfb28...` | CI-maintained multi-arch index digest. |
| `replicaCount` | `1` | Single node; VictoriaLogs is not scaled by replicas. |
| `containerPort` | `9428` | HTTP listen port (wired to `-httpListenAddr`). |
| `storagePath` | `/victoria-logs-data` | Data dir (`-storageDataPath`); the PVC mount point. |
| `persistence.enabled` | `true` | Provision a PVC for the storage dir. |
| `persistence.size` | `10Gi` | PVC size. |
| `service.port` | `9428` | ClusterIP service port. |
| `resources` | `100m/128Mi` .. `1/1Gi` | Requests / limits. |
| `networkPolicy.enabled` | `true` | Restrict ingress to the namespace unless `allowExternal`. |
| `podDisruptionBudget.enabled` | `true` | Keep 1 pod available during disruptions. |
| `args` | `[]` | Extra flags passed to `victoria-logs`. |

The container runs read-only-rootfs, nonroot (uid 1001), all capabilities
dropped; only the mounted storage dir is writable.

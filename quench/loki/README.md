# Quenchworks Loki

Hardened [Grafana Loki](https://github.com/grafana/loki) log aggregation system,
running in **single-binary mode** (`-target=all`, every component in one process)
on a minimal, nonroot, 0-CVE image pinned by digest. Built from source on Wolfi.
Loki has no UI of its own — Grafana is its frontend. The HTTP API (push, query,
`/ready`, `/metrics`) is on port 3100; gRPC on 9095.

## Install

```bash
helm install loki oci://ghcr.io/quenchworks/charts/loki
```

## Push logs

Loki does not collect logs itself — point an agent (Promtail, Grafana Alloy, the
OpenTelemetry Collector) or curl at the push endpoint:

```bash
curl -H 'Content-Type: application/json' \
  -XPOST 'http://loki-loki:3100/loki/api/v1/push' \
  --data-raw '{"streams":[{"stream":{"app":"demo"},"values":[["'"$(date +%s)000000000"'","hello loki"]]}]}'
```

## Query (LogQL)

```bash
curl -G 'http://loki-loki:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={app="demo"}'
```

## Use as a Grafana datasource

Grafana is Loki's UI. Add a **Loki** datasource pointing at the in-cluster service:

```
http://loki-loki.<namespace>.svc.cluster.local:3100
```

Then browse streams in Grafana's Explore view. Pairs with the Quenchworks
`grafana` chart.

## Configure

The full Loki config lives in `lokiConfig` and is rendered (templated) into a
ConfigMap mounted at `/etc/loki/config.yaml`. The default is a sane single-binary
config: anonymous auth, filesystem storage under `/loki`, an in-memory ring with
`replication_factor: 1`, and a current `tsdb` `v13` schema. Replace it wholesale
to bring your own:

```yaml
lokiConfig: |
  auth_enabled: false
  server:
    http_listen_port: {{ .Values.service.port }}
    grpc_listen_port: {{ .Values.service.grpcPort }}
  common:
    path_prefix: /loki
    storage:
      filesystem:
        chunks_directory: /loki/chunks
        rules_directory: /loki/rules
    replication_factor: 1
    ring:
      kvstore:
        store: inmemory
  schema_config:
    configs:
      - from: 2020-10-24
        store: tsdb
        object_store: filesystem
        schema: v13
        index: { prefix: index_, period: 24h }
```

`helm upgrade` rolls the pod on the config checksum.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/loki \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/loki` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single-binary mode; keep at 1 (scale-out needs an object store + real ring). |
| `lokiConfig` | single-binary filesystem config | Full Loki config, templated, mounted from a ConfigMap. |
| `extraArgs` | `[]` | Raw flags appended after `-config.file`/`-target`. |
| `persistence.enabled` | `true` | 16Gi PVC mounted at `/loki` (chunks/index/wal/compactor). |
| `service.port` | `3100` | HTTP API (push, query, `/ready`, `/metrics`). |
| `service.grpcPort` | `9095` | gRPC (inter-component / scale-out). |
| `networkPolicy.enabled` | `true` | Restricts HTTP + gRPC ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The only writable state is the `/loki` volume (chunks/index/wal/
compactor/rules) and a `/tmp` emptyDir. Loki has **no built-in authentication**
(`auth_enabled: false`) — there is no Secret to manage. The NetworkPolicy is the
trust boundary; keep it enabled, and front the service with an authenticating
proxy if you must expose it beyond the cluster.

## Notes

Single-binary mode (`-target=all`) is the recommended topology up to a few hundred
GB/day of ingest. The microservices read/write/backend split and an external
object store (S3-compatible, e.g. the Quenchworks `seaweedfs`/`garage`/`rustfs`
charts) are tracked follow-ups. Depends on the `quench-common` library chart,
pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

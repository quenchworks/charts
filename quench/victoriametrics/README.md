# Quenchworks VictoriaMetrics

Hardened [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics)
single-node TSDB on a minimal, nonroot, 0-CVE image pinned by digest. A single
self-contained Go binary exposing a Prometheus-compatible HTTP API on port 8428.

## Install

```bash
helm install vm oci://ghcr.io/quenchworks/charts/victoriametrics
```

## Ingest

Point Prometheus `remote_write` at the service:

```yaml
remote_write:
  - url: http://vm-victoriametrics:8428/api/v1/write
```

Or import samples directly in Prometheus exposition format:

```bash
kubectl run q --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c "curl -d 'quench_metric 123' http://vm-victoriametrics:8428/api/v1/import/prometheus"
```

## Query

```bash
# instant query
curl 'http://vm-victoriametrics:8428/api/v1/query?query=quench_metric'
# range query (use this to read back a just-written point, which can fall outside
# the instant query's staleness window)
curl 'http://vm-victoriametrics:8428/api/v1/query_range?query=quench_metric&start=-5m&step=30s'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/victoriametrics \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/victoriametrics` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; the clustered topology is a follow-up. |
| `config.retentionPeriod` | `"1"` | `-retentionPeriod` (VM duration shorthand; `1` = 1 month). |
| `config.extraArgs` | `[]` | Raw flags appended to the server. |
| `persistence.enabled` | `true` | 16Gi PVC mounted at `/storage`. |
| `service.port` | `8428` | The single HTTP API port (read/write/query). |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Data lives on the writable `/storage` PVC. VictoriaMetrics has **no
built-in authentication** — there is no Secret to manage. The NetworkPolicy is
the trust boundary; keep it enabled, and front the service with an authenticating
proxy if you must expose it beyond the cluster.

## Notes

Single node. The clustered topology (`vminsert` / `vmselect` / `vmstorage`) is a
tracked follow-up. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

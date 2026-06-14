# Quenchworks Fluent Bit

Hardened [Fluent Bit](https://github.com/fluent/fluent-bit) — a lightweight,
high-performance log and metrics processor and shipper — on a minimal, nonroot,
0-CVE image pinned by digest. Built from source on Wolfi (CMake) from the upstream
`v5.0.7` tag.

Ships in **deployment (gateway/aggregator) mode**: a standalone Deployment that
receives logs (e.g. over the `forward` input), processes them, and ships them out.

> **DaemonSet note.** The *common* node-log-collection pattern is a per-node
> DaemonSet (one Fluent Bit per node tailing `/var/log/containers` via the `tail`
> input). That variant needs host mounts and a ServiceAccount with pod-metadata
> read access; it is a tracked follow-up. Only `deployment` mode is supported here.

## Install

```bash
helm install logs oci://ghcr.io/quenchworks/charts/fluent-bit
```

## Send logs in / ship logs out

The entire Fluent Bit config lives in the `config` value (classic `.conf` format),
is rendered into a ConfigMap, mounted at `/fluent-bit/etc/fluent-bit.conf`, and
passed to the binary with `-c`. Override it wholesale to wire real inputs/outputs.

Out of the box the pipeline keeps the HTTP monitoring server on `:2020`, reads a
`dummy` input, and writes to `stdout` (logged, not shipped). Inspect it with:

```bash
kubectl logs deploy/logs-fluent-bit
```

A real **forward-in → loki-out** aggregator:

```yaml
config: |
  [SERVICE]
      HTTP_Server  On
      HTTP_Listen  0.0.0.0
      HTTP_Port    2020
      Health_Check On
  [INPUT]
      Name   forward
      Listen 0.0.0.0
      Port   24224
  [OUTPUT]
      Name   loki
      Match  *
      Host   loki.logging.svc.cluster.local
      Port   3100
      Labels job=fluent-bit
```

`helm upgrade` rolls the pod on the config checksum. Keep the `[SERVICE]` HTTP
server on `:2020` (the probes depend on `/api/v1/health`).

- **Common inputs:** `tail` (container/app log files), `forward` (from other
  Fluent Bit / Fluentd agents on `:24224`), `http`, `systemd`.
- **Common outputs:** `loki`, `es` (Elasticsearch/OpenSearch), `forward` (to an
  aggregator), `http`, `stdout`.

If you add a network input like `forward` on `:24224`, expose it on the Service
with `extraVolumes`/`extraVolumeMounts`-style overrides or by editing the chart;
the default Service only publishes the `:2020` monitoring port.

## Scrape the metrics

Fluent Bit exposes its own metrics on the HTTP monitoring server (`:2020`):

```bash
# JSON
curl http://logs-fluent-bit:2020/api/v1/metrics
# Prometheus exposition format
curl http://logs-fluent-bit:2020/api/v1/metrics/prometheus
```

Add a Prometheus scrape job against `:2020/api/v1/metrics/prometheus`.

## Health and the HTTP server

The `[SERVICE]` block enables the HTTP monitoring server:

- `GET /api/v1/health` on `:2020` → `200` (used for liveness and readiness).
- `GET /` on `:2020` → JSON dashboard.
- `GET /api/v1/uptime` on `:2020` → uptime JSON.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/fluent-bit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/fluent-bit` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `mode` | `deployment` | Gateway/aggregator mode. DaemonSet is a follow-up. |
| `replicaCount` | `1` | Stateless default pipeline; scale out for forward-ingest. |
| `config` | dummy → stdout + HTTP `:2020` | The full Fluent Bit config (classic `.conf`), templated to `/fluent-bit/etc/fluent-bit.conf`. |
| `service.ports.http` | `2020` | HTTP monitoring server (health + metrics + dashboard). |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped; `/tmp` and `/var/log/flb-storage` (filesystem buffering) are writable
`emptyDir`s. Fluent Bit's HTTP monitoring server has **no built-in
authentication** — the NetworkPolicy is the trust boundary. Front any network
input you expose beyond the cluster with an authenticating proxy or mTLS.

## Notes

Deployment (gateway/aggregator) mode. The default `dummy → stdout` pipeline logs
rather than ships logs; wire a real input/output for production. Depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

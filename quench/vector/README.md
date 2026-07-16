# Quenchworks Vector

Hardened [Vector](https://github.com/vectordotdev/vector) (high-performance
observability data pipeline for logs and metrics) on a minimal, nonroot, 0-CVE
image pinned by digest, cosign-signed (keyless / Sigstore). Built from source on
Wolfi from the upstream `v0.56.0` git tag with a curated, CVE-light feature set.

Ships in **aggregator mode**: a standalone Deployment that receives/scrapes
telemetry, transforms it (VRL), and forwards it. A per-node `agent` DaemonSet
variant (host metrics / log tailing on every node) is a tracked follow-up.

## Install

```bash
helm install vector oci://ghcr.io/quenchworks/charts/vector
```

## The default sink is `console` (logs, does not forward)

By default the pipeline generates demo log events (`demo_logs` source) and
writes them to the `console` sink, which **logs** to Vector's stdout and forwards
nowhere:

```bash
kubectl logs deploy/vector-vector
```

This keeps the chart self-contained. Add a real source/sink before production use.

## Override the config

The entire Vector config lives in the `vectorConfig` value, is rendered into a
ConfigMap, mounted at `/etc/vector/vector.yaml`, and passed as `--config`. Override
it wholesale:

```yaml
vectorConfig:
  api:
    enabled: true                 # keep on: the probes hit /health on :8686
    address: "0.0.0.0:8686"
  sources:
    in:
      type: prometheus_scrape
      endpoints: ["http://target:9100/metrics"]
  transforms:
    shape:
      type: remap                 # VRL
      inputs: ["in"]
      source: '.cluster = "prod"'
  sinks:
    out:
      type: loki                  # forward to a real backend
      inputs: ["shape"]
      endpoint: "http://loki:3100"
      encoding: { codec: json }
      labels: { source: "vector" }
```

`helm upgrade` rolls the pod on the config checksum. Keep `api.enabled: true` so
the liveness/readiness probes (`GET /health` on `:8686`) pass.

## Available components

The image is built with a curated feature set (kafka, pulsar, nats, and the
AWS/GCP/Azure/mongodb native components are **trimmed** to keep it lean and 0-CVE):

- **Sources**: `demo_logs`, `file`, `http_server`, `http_client`, `syslog`,
  `socket`, `statsd`, `prometheus_scrape`, `host_metrics`, `internal_logs`,
  `internal_metrics`, `opentelemetry`, `vector`
- **Transforms**: all of them, including `remap` (VRL), `filter`, `route`,
  `reduce`, `sample`, `throttle`, `log_to_metric`, ...
- **Sinks**: `console`, `blackhole`, `file`, `http`, `loki`, `elasticsearch`,
  `prometheus_exporter`, `socket`, `opentelemetry`, `vector`

## The API (health + GraphQL) on :8686

With `api.enabled: true` Vector serves its GraphQL playground at `/` and a health
endpoint at `/health` (returns `{"ok":true}`) on `:8686`:

```bash
curl http://vector-vector:8686/health
```

`service.exposeApi` is `true` by default.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vector \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/vector --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/vector` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `mode` | `deployment` | Aggregator mode. DaemonSet agent is a follow-up. |
| `replicaCount` | `1` | Stateless default pipeline; scale out for throughput. |
| `vectorConfig` | demo_logs -> console + api:8686 | The full Vector config (templated to `/etc/vector/vector.yaml`). |
| `service.ports.api` | `8686` | Vector GraphQL + `GET /health` (probe target). |
| `service.exposeApi` | `true` | Publish `:8686` on the Service. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped; `/tmp` and the data dir (`/vector-data-dir`, `VECTOR_DATA_DIR`, used for
disk buffers) are writable emptyDir volumes. Vector's API has **no built-in
authentication** — the NetworkPolicy is the trust boundary. Front any receiving
sources (http_server, syslog, socket, opentelemetry, vector) with an
authenticating proxy or mTLS if you expose them beyond the cluster.

## Notes

Aggregator mode (Deployment). The default `console` sink logs rather than forwards
telemetry; add a real sink for production. Depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Tempo

Hardened [Grafana Tempo](https://github.com/grafana/tempo) distributed tracing
backend, running in **single-binary mode** (`-target=all`, every component in one
process) on a minimal, nonroot, 0-CVE image, cosign-signed (keyless / Sigstore)
and pinned by digest. Built from source on Wolfi. Tempo has no UI of its own — Grafana is its frontend. The HTTP API (query,
`/ready`, `/metrics`) is on port 3200; OTLP receivers on 4317 (gRPC) and 4318
(HTTP); gRPC on 9095.

## Install

```bash
helm install tempo oci://ghcr.io/quenchworks/charts/tempo
```

## Send traces

Tempo does not collect spans itself — point an OpenTelemetry SDK, the OpenTelemetry
Collector, or Grafana Alloy at the OTLP receivers:

```
OTLP gRPC:  tempo-tempo:4317
OTLP HTTP:  http://tempo-tempo:4318/v1/traces
```

Quick OTLP/HTTP smoke (POST a span, expect 200):

```bash
curl -fsS -X POST 'http://tempo-tempo:4318/v1/traces' \
  -H 'Content-Type: application/json' \
  -d '{"resourceSpans":[{"scopeSpans":[{"spans":[{"traceId":"5b8efff798038103d269b633813fc60c","spanId":"eee19b7ec3c1b173","name":"demo","kind":1,"startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000000000001000"}]}]}]}'
```

## Use as a Grafana datasource

Grafana is Tempo's UI. Add a **Tempo** datasource pointing at the in-cluster service:

```
http://tempo-tempo.<namespace>.svc.cluster.local:3200
```

Then search and view traces in Grafana's Explore view. Pairs with the Quenchworks
`grafana` and `loki` charts (logs ↔ traces correlation).

## Configure

The full Tempo config lives in `tempoConfig` and is rendered (templated) into a
ConfigMap mounted at `/etc/tempo/config.yaml`. The default is a sane single-binary
config: OTLP receivers on 4317/4318, a filesystem trace backend with blocks and WAL
under `/var/tempo`, a compactor with finite retention, and usage reporting off.
Replace it wholesale to bring your own:

```yaml
tempoConfig: |
  target: all
  server:
    http_listen_port: {{ .Values.service.port }}
    grpc_listen_port: {{ .Values.service.grpcPort }}
  distributor:
    receivers:
      otlp:
        protocols:
          grpc: { endpoint: 0.0.0.0:{{ .Values.service.otlpGrpcPort }} }
          http: { endpoint: 0.0.0.0:{{ .Values.service.otlpHttpPort }} }
  storage:
    trace:
      backend: local
      wal: { path: /var/tempo/wal }
      local: { path: /var/tempo/traces }
```

`helm upgrade` rolls the pod on the config checksum.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tempo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/tempo --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/tempo` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single-binary mode; keep at 1 (scale-out needs an object store). |
| `tempoConfig` | single-binary filesystem config | Full Tempo config, templated, mounted from a ConfigMap. |
| `extraArgs` | `[]` | Raw flags appended after `-config.file`/`-target`. |
| `persistence.enabled` | `true` | 16Gi PVC mounted at `/var/tempo` (trace blocks + WAL). |
| `service.port` | `3200` | HTTP API (query, `/ready`, `/metrics`). |
| `service.otlpGrpcPort` | `4317` | OTLP gRPC receiver. |
| `service.otlpHttpPort` | `4318` | OTLP HTTP receiver (`/v1/traces`). |
| `service.grpcPort` | `9095` | gRPC (inter-component / scale-out). |
| `networkPolicy.enabled` | `true` | Restricts HTTP + OTLP + gRPC ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The only writable state is the `/var/tempo` volume (trace blocks + WAL)
and a `/tmp` emptyDir. Tempo has **no built-in authentication** — there is no
Secret to manage. The NetworkPolicy is the trust boundary; keep it enabled, and
front the service with an authenticating proxy if you must expose it beyond the
cluster.

## Notes

Single-binary mode (`-target=all`) is the recommended topology up to moderate
ingest. The microservices distributor/ingester/querier/compactor split and an
external object store (S3-compatible, e.g. the Quenchworks
`seaweedfs`/`garage`/`rustfs` charts) are tracked follow-ups. Depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

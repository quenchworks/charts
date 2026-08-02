# Quenchworks Fluent Bit

Hardened [Fluent Bit](https://github.com/fluent/fluent-bit), a lightweight log
and metrics processor and shipper, on a minimal, nonroot, 0-CVE image pinned by
digest and cosign-signed (keyless / Sigstore). Built from source on Wolfi
(CMake) from the upstream `v5.0.7` tag. It ships in deployment
(gateway/aggregator) mode: a standalone Deployment that receives logs (for
example over the `forward` input), processes them, and ships them out.

## Install

```bash
helm install logs oci://ghcr.io/quenchworks/charts/fluent-bit
```

The whole Fluent Bit config lives in the `config` value (classic `.conf`
format). Override it to wire real inputs and outputs:

```bash
helm install logs oci://ghcr.io/quenchworks/charts/fluent-bit \
  --set-file config=./fluent-bit.conf
```

Out of the box the pipeline keeps the HTTP monitoring server on `:2020`, reads a
`dummy` input, and writes to `stdout` (logged, not shipped). Inspect it with:

```bash
kubectl logs deploy/logs-fluent-bit
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/fluent-bit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/fluent-bit --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/fluent-bit` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `mode` | `deployment` | Gateway/aggregator mode. DaemonSet is a follow-up. |
| `replicaCount` | `1` | Stateless default pipeline; scale out for forward-ingest. |
| `config` | dummy → stdout + HTTP `:2020` | The full Fluent Bit config (classic `.conf`), rendered to a ConfigMap and mounted at `/fluent-bit/etc/fluent-bit.conf`. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.ports.http` | `2020` | HTTP monitoring server (health + metrics + dashboard). |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A single Deployment runs Fluent Bit as a gateway/aggregator. The `config` value
renders to a ConfigMap mounted read-only at `/fluent-bit/etc/fluent-bit.conf`
and passed to the binary with `-c`; a `helm upgrade` rolls the pod on the config
checksum. Keep the `[SERVICE]` block's HTTP server on `:2020`, since liveness
and readiness both hit `GET /api/v1/health` there. The same server also answers
`GET /` (JSON dashboard), `GET /api/v1/uptime`, and the metrics endpoints below.
The default Service publishes only the `:2020` monitoring port; a network input
such as `forward` on `:24224` needs its own port added to the Service.

The default `dummy → stdout` pipeline is stateless, so the workload scales
horizontally with no coordination (raise `replicaCount` for forward-ingest
throughput). The container runs nonroot (uid 1001) on a read-only root
filesystem with all capabilities dropped; `/tmp` and `/var/log/flb-storage`
(filesystem buffering) are writable `emptyDir`s. Fluent Bit's HTTP monitoring
server has no built-in authentication, so the NetworkPolicy is the trust
boundary. Front any network input you expose beyond the cluster with an
authenticating proxy or mTLS.

The common node-log-collection pattern is a per-node DaemonSet (one Fluent Bit
per node tailing `/var/log/containers` via the `tail` input). That variant needs
host mounts and a ServiceAccount with pod-metadata read access; it is a tracked
follow-up. Only `deployment` mode is supported here.

Common inputs are `tail` (container/app log files), `forward` (from other Fluent
Bit or Fluentd agents on `:24224`), `http`, and `systemd`. Common outputs are
`loki`, `es` (Elasticsearch/OpenSearch), `forward` (to an aggregator), `http`,
and `stdout`.

## Configuration examples

A real forward-in → loki-out aggregator:

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

Fluent Bit exposes its own metrics on the `:2020` monitoring server. Add a
Prometheus scrape job against `/api/v1/metrics/prometheus`:

```bash
# JSON
curl http://logs-fluent-bit:2020/api/v1/metrics
# Prometheus exposition format
curl http://logs-fluent-bit:2020/api/v1/metrics/prometheus
```

## Uninstall

```bash
helm uninstall logs
```

The pipeline is stateless and holds no PVCs, so nothing persists.

## Notes

Deployment (gateway/aggregator) mode only. The default `dummy → stdout` pipeline
logs rather than ships logs; wire a real input and output before relying on it
in production. The chart depends on the `quench-common` library chart, pulled
from `oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

# Quenchworks Mimir

Hardened [Grafana Mimir](https://github.com/grafana/mimir) — horizontally scalable,
long-term storage for Prometheus metrics — running in **single-process (monolithic)
mode** (`-target=all`, every component in one process) on a minimal, nonroot, 0-CVE
image pinned by digest. Built from source on Wolfi. Mimir has no UI of its own —
Grafana is its frontend. The HTTP API (remote-write, query, `/ready`, `/metrics`)
is on port 8080; gRPC on 9095.

## Install

```bash
helm install mimir oci://ghcr.io/quenchworks/charts/mimir
```

## Send metrics (Prometheus remote-write)

Mimir does not scrape targets itself — point Prometheus, Grafana Alloy, or the
OpenTelemetry Collector at the push endpoint:

```yaml
remote_write:
  - url: http://mimir-mimir:8080/api/v1/push
```

## Query (PromQL)

This instance runs single-tenant (`multitenancy_enabled: false`):

```bash
curl -G 'http://mimir-mimir:8080/prometheus/api/v1/query' \
  --data-urlencode 'query=up'
```

## Use as a Grafana datasource

Grafana is Mimir's UI. Add a **Prometheus** datasource pointing at the in-cluster
service (note the `/prometheus` prefix):

```
http://mimir-mimir.<namespace>.svc.cluster.local:8080/prometheus
```

Pairs with the Quenchworks `grafana` chart.

## Configure

The full Mimir config lives in `mimirConfig` and is rendered (templated) into a
ConfigMap mounted at `/etc/mimir/mimir.yaml`. The default is a sane single-node
config: single-tenant, filesystem object storage for blocks/ruler/alertmanager
under `/data`, single-node rings over memberlist with `replication_factor: 1`.
Replace it wholesale to bring your own (e.g. an S3/GCS object store for
scale-out). `helm upgrade` rolls the pod on the config checksum.

> This default config is **not for production**: it is a single node with a local
> filesystem object store and `replication_factor: 1`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mimir \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/mimir --owner quenchworks`.

## Values

| Key                           | Default                            | Notes                                                                                     |
| ----------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/mimir` |                                                                                           |
| `image.digest`                | (CI-written)                       | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                | Monolithic mode; keep at 1 (scale-out needs an object store + real ring).                 |
| `mimirConfig`                 | single-node filesystem config      | Full Mimir config, templated, mounted from a ConfigMap.                                   |
| `extraArgs`                   | `[]`                               | Raw flags appended after `-config.file`/`-target`.                                        |
| `persistence.enabled`         | `true`                             | 16Gi PVC mounted at `/data` (TSDB, filesystem object store, compactor).                   |
| `service.port`                | `8080`                             | HTTP API (remote-write, query, `/ready`, `/metrics`).                                     |
| `service.grpcPort`            | `9095`                             | gRPC (inter-component / scale-out).                                                       |
| `networkPolicy.enabled`       | `true`                             | Restricts HTTP + gRPC ingress to the release namespace.                                   |
| `podDisruptionBudget.enabled` | `true`                             | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                            | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                               | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                               | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                             | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                               | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                               | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The only writable state is the `/data` volume (TSDB, filesystem object
store, compactor/ruler working dirs) and a `/tmp` emptyDir. Mimir runs single-tenant
(`multitenancy_enabled: false`) — there is no Secret to manage. The NetworkPolicy is
the trust boundary; keep it enabled, and front the service with an authenticating
proxy if you must expose it beyond the cluster.

## Notes

Single-process (monolithic) mode (`-target=all`) is the recommended topology for a
single node. The microservices split (distributor/ingester/querier/store-gateway/
compactor as separate deployments) and an external S3-compatible object store (e.g.
the Quenchworks `seaweedfs`/`garage`/`rustfs` charts) are tracked follow-ups.
Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

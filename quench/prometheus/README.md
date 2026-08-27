# Quenchworks Prometheus

Hardened [Prometheus](https://github.com/prometheus/prometheus) single-node
metrics server / TSDB on a minimal, nonroot, 0-CVE image pinned by digest. The
server is built from source on Wolfi (UI embedded via `builtinassets`) and
exposes the HTTP API + UI on port 9090, running on a read-only root filesystem
with all capabilities dropped. The image is cosign-signed (keyless / Sigstore)
and the chart pins it by the signed digest, never a tag.

## Install

```bash
helm install prom oci://ghcr.io/quenchworks/charts/prometheus
```

Size the TSDB volume and pick a storage class:

```bash
helm install prom oci://ghcr.io/quenchworks/charts/prometheus \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/prometheus \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/prometheus --owner quenchworks`.

## Values

| Key                           | Default                                 | Notes                                                                                                 |
| ----------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/prometheus` |                                                                                                       |
| `image.digest`                | (CI-written)                            | Required. Charts pin by digest, never a tag.                                                          |
| `replicaCount`                | `1`                                     | Single node.                                                                                          |
| `config.prometheusYaml`       | self-scrape                             | The full `prometheus.yml`, mounted from a ConfigMap.                                                  |
| `config.retentionTime`        | `"15d"`                                 | `--storage.tsdb.retention.time` (Prometheus duration).                                                |
| `config.extraArgs`            | `[]`                                    | Raw flags appended to the server (e.g. retention.size).                                               |
| `persistence.enabled`         | `true`                                  | 16Gi PVC mounted at `/prometheus` (TSDB). When `false`, uses an `emptyDir` (data is lost on restart). |
| `persistence.size`            | `16Gi`                                  | Requested volume size.                                                                                |
| `persistence.existingClaim`   | `""`                                    | Bind an existing PVC instead of provisioning one.                                                     |
| `service.port`                | `9090`                                  | HTTP API + UI + lifecycle endpoints.                                                                  |
| `networkPolicy.enabled`       | `true`                                  | Restricts HTTP ingress to the release namespace.                                                      |
| `podDisruptionBudget.enabled` | `true`                                  | `minAvailable: 1`.                                                                                    |
| `ingress.enabled`             | `false`                                 | Create an Ingress for this chart. HTTP only.                                                          |
| `ingress.className`           | `""`                                    | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                      |
| `ingress.annotations`         | `{}`                                    | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                        |
| `ingress.servicePort`         | `null`                                  | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.                    |
| `ingress.hosts`               | `[]`                                    | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.             |
| `ingress.tls`                 | `[]`                                    | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.                  |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

Prometheus runs as a **StatefulSet** so the node keeps a stable network identity
and its own persistent volume, fronted by a headless Service. The TSDB lives on a
single volume mounted at `/prometheus`, provisioned by a `volumeClaimTemplate`;
set `persistence.existingClaim` to reuse an existing PVC, or
`persistence.enabled=false` to fall back to an `emptyDir` that does not survive a
restart.

The image is flag- and file-driven. Its entrypoint pins `--config.file`,
`--storage.tsdb.path` (`PROM_TSDB_PATH`, the writable PVC), `--web.listen-address`
(`PROM_WEB_LISTEN`), and `--web.enable-lifecycle`; `config.retentionTime` becomes
`--storage.tsdb.retention.time` and `config.extraArgs` are appended verbatim
through the entrypoint's `"$@"`. `config.prometheusYaml` renders to a ConfigMap
and is mounted read-only over `/etc/prometheus/prometheus.yml` by `subPath`,
leaving the rest of `/etc/prometheus` on the read-only rootfs intact; `/tmp` is a
writable `emptyDir` for scratch.

Port **9090** carries the HTTP API, the UI, and the lifecycle endpoints. Probes
use the lifecycle endpoints: liveness on `/-/healthy` and readiness on `/-/ready`.
The container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped.

## Configuration examples

Override the scrape config and retention. `helm upgrade` rolls the pod on the
config checksum:

```yaml
config:
  prometheusYaml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]
      - job_name: node-exporter
        static_configs:
          - targets: ["node-exporter:9100"]
  retentionTime: "30d"
  extraArgs:
    - --storage.tsdb.retention.size=10GB
```

For a live reload without a restart (`--web.enable-lifecycle` is on by default):

```bash
curl -XPOST http://prom-prometheus:9090/-/reload
```

Query over the HTTP API:

```bash
# instant query
curl 'http://prom-prometheus:9090/api/v1/query?query=up'
# range query
curl 'http://prom-prometheus:9090/api/v1/query_range?query=up&start=-5m&end=now&step=30s'
```

## Uninstall

```bash
helm uninstall prom
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the TSDB gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=prom
```

## Notes

Single node. Prometheus' HA story (two identical replicas) and remote-write to a
long-term store (VictoriaMetrics) are tracked follow-ups. Pairs with the
Quenchworks exporters as scrape targets and Grafana for dashboards. Prometheus
has no built-in authentication and there is no Secret to manage; the NetworkPolicy
is the trust boundary, so keep it enabled and front the service with an
authenticating proxy if you must expose it beyond the cluster. Depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

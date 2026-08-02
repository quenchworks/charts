# Quenchworks coroot

Hardened [Coroot](https://github.com/coroot/coroot) — an open-source
observability/APM server that turns eBPF-collected metrics, logs, traces and
profiles into service maps, SLOs and cost insights — on a minimal, nonroot,
0-CVE image pinned by digest. It serves its embedded Vue UI and JSON API on port
8080 and runs a built-in OTLP gRPC collector on 4317, on a read-only root
filesystem with all capabilities dropped. The image is cosign-signed (keyless /
Sigstore) and the chart pins it by the signed digest, never a tag.

This is the Community edition: a single Go server with an embedded SQLite store.
It keeps configuration, cache and local state under `/data`.

## Install

```bash
helm install my-coroot oci://ghcr.io/quenchworks/charts/coroot
```

Size the data volume and pick a storage class:

```bash
helm install my-coroot oci://ghcr.io/quenchworks/charts/coroot \
  --set persistence.size=20Gi \
  --set persistence.storageClass=fast-ssd
```

Coroot needs a Prometheus for metrics and, for logs and traces, a ClickHouse
backend. Point it at yours with `extraEnvVars` (see Configuration examples). The
UI is usually opened from a browser outside the cluster; to allow ingress from
any source (default restricts it to the release namespace):

```bash
helm install my-coroot oci://ghcr.io/quenchworks/charts/coroot \
  --set networkPolicy.allowExternal=true
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/coroot \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/coroot \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/coroot` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Fixed at 1. Community edition is single-node (embedded SQLite); see Architecture. |
| `persistence.enabled` | `true` | 10Gi PVC mounted at `/data`. When `false`, uses an `emptyDir` (state is lost on restart). |
| `persistence.size` | `10Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.httpPort` | `8080` | UI + JSON API port. |
| `service.otlpPort` | `4317` | Built-in OTLP gRPC collector (telemetry ingest). |
| `resources.requests` | `200m / 256Mi` | CPU / memory requests. |
| `resources.limits` | `1 / 1Gi` | CPU / memory limits. |
| `command` | `[]` | Override the entrypoint. Empty uses the baked-in `/usr/bin/coroot`. |
| `args` | `[]` | Override server args. Empty uses the hardened defaults. |
| `extraEnvVars` | `[]` | Extra env vars. Coroot reads all settings from flags or matching env vars. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts HTTP/OTLP ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`, `lifecycleHooks`,
`podSecurityContext`, `containerSecurityContext`, and the probe overrides
(`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Coroot runs as a **StatefulSet** with a single replica. The Community edition is
one Go process that embeds its Vue UI (`//go:embed`) and keeps its state — the
SQLite config DB and the local metrics cache — under `/data`. That directory is a
persistent volume provisioned by a `volumeClaimTemplate`; with
`persistence.enabled=false` it becomes an `emptyDir` and does not survive a
restart. Do not raise `replicaCount`: multiple pods would contend for the same
store.

Two ports are exposed. **HTTP (8080)** serves the UI and the JSON API. **OTLP
(4317)** is coroot's built-in gRPC collector for ingesting traces, metrics and
logs from instrumented services. The image bakes `LISTEN=:8080` and
`DATA_DIR=/data`, so the entrypoint runs correctly with no argument overrides.
Probes: a TCP liveness check on the HTTP port and an HTTP readiness check against
`/health`.

Coroot itself is a UI and query layer. It does not store metrics long-term; it
reads them from a **Prometheus** you point it at, and reads logs and traces from
a **ClickHouse** backend. Neither is bundled by this chart — configure them at
first run or through the UI.

## Configuration examples

Point coroot at an in-cluster Prometheus at install time and give it a larger
volume:

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
extraEnvVars:
  - name: BOOTSTRAP_PROMETHEUS_URL
    value: http://prometheus.monitoring.svc:9090
  - name: BOOTSTRAP_REFRESH_INTERVAL
    value: 15s
```

Bind an existing PVC instead of provisioning a new one:

```yaml
persistence:
  enabled: true
  existingClaim: my-coroot-data
```

Read-only demo with no persistence (state is lost on restart):

```yaml
persistence:
  enabled: false
```

## Uninstall

```bash
helm uninstall my-coroot
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-coroot
```

## Notes

Community (single-node) edition only; clustered coroot and external Postgres /
ClickHouse-backed storage are upstream Enterprise features and out of scope here.
The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the server is
pinned by digest.

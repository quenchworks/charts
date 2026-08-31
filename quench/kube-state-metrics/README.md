# Quenchworks kube-state-metrics

Hardened [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics), the
Kubernetes add-on that listens to the API server and exposes the state of cluster
objects — Deployments, Pods, Nodes, Jobs, PVCs, HPAs and more — as Prometheus
metrics, on a minimal, nonroot, 0-CVE image built from source, cosign-signed and
pinned by digest. Runs as a stateless Deployment; object metrics on `8080`, health
and its own process metrics on `8081`.

It exports cluster *state*, not resource usage: `kube_deployment_status_replicas`,
`kube_pod_container_status_restarts_total`, `kube_job_failed`. For CPU/memory usage
see `metrics-server` (for `kubectl top` and HPAs) or the kubelet's cAdvisor endpoint.

## Install

```bash
helm install ksm oci://ghcr.io/quenchworks/charts/kube-state-metrics
```

```bash
kubectl port-forward svc/ksm-kube-state-metrics 8080:8080
curl -s http://127.0.0.1:8080/metrics | grep -m5 '^kube_'
```

The chart's pods carry `prometheus.io/scrape` annotations, so a Prometheus using
annotation-based pod discovery finds it with no further configuration. Using
ServiceMonitor/PodMonitor or a static config instead? Set `podAnnotations: {}` and
scrape the Service directly.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kube-state-metrics \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/kube-state-metrics --owner quenchworks`.

## Values

| Key                             | Default                                             | Notes                                                                                                     |
| ------------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `image.repository`              | `ghcr.io/quenchworks/images/kube-state-metrics`     |                                                                                                           |
| `image.digest`                  | (CI-written)                                        | Required. Charts pin by digest, never a tag.                                                              |
| `image.pullPolicy`              | `IfNotPresent`                                      |                                                                                                           |
| `nameOverride`                  | `""`                                                | Override the chart name in resource names.                                                                |
| `replicaCount`                  | `1`                                                 | Keep at 1 unless sharding — unsharded replicas export duplicate series. No HPA, deliberately.             |
| `extraArgs`                     | `[]`                                                | Extra exporter flags (`--namespaces`, `--resources`, `--metric-labels-allowlist`, `--shard`).             |
| `resources.requests`            | `cpu 20m / mem 64Mi`                                | Memory scales with object count; raise the limit on large clusters.                                       |
| `resources.limits`              | `cpu 500m / mem 512Mi`                              |                                                                                                           |
| `service.type`                  | `ClusterIP`                                         | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                               |
| `service.port`                  | `8080`                                              | Object metrics — the port Prometheus scrapes.                                                             |
| `service.telemetryPort`         | `8081`                                              | The exporter's own process metrics plus `/healthz`, `/livez`, `/readyz`.                                  |
| `podAnnotations`                | `prometheus.io/scrape,port,path`                    | Annotation-based discovery. Set `{}` when using ServiceMonitor/PodMonitor.                                 |
| `serviceAccount.create`         | `true`                                              | Token automount is **on** — the exporter is an API-server client.                                          |
| `serviceAccount.name`           | `""`                                                | Use an existing ServiceAccount.                                                                           |
| `rbac.create`                   | `true`                                              | Required. Cluster-wide `list`/`watch` on the exported object kinds; read-only.                            |
| `networkPolicy.enabled`         | `true`                                              | Restricts ingress to both listeners.                                                                      |
| `networkPolicy.allowExternal`   | `false`                                             | Same-namespace only by default; add `networkPolicy.extraFrom` for a Prometheus elsewhere.                 |
| `podDisruptionBudget.enabled`   | `false`                                             | Off: one unsharded replica cannot be both protected and evictable. Enable when sharded.                   |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs the exporter, which holds no data of its own: it rebuilds
its entire metric set from API-server watches, so it needs no storage and restarts
cleanly. Two listeners, kept separate on purpose — object metrics on `8080` and
telemetry/health on `8081`. The probes are split across them, matching upstream:
liveness hits `/livez` on the metrics port (proving the object-metrics server is up),
while readiness hits `/readyz` on the telemetry port, which answers immediately —
probing the metrics port for readiness would flap on a large cluster where a scrape
takes seconds.

RBAC is cluster-scoped and read-only — one `list`/`watch` grant per exported object
kind, no write verb anywhere. The ClusterRole and ClusterRoleBinding names carry the
release namespace, so two releases in different namespaces do not collide on one
global object. `secrets` and `configmaps` are `list`/`watch` only and no exported
metric carries their contents (names, types and counts only); drop those two lines
from the ClusterRole if your policy forbids the verbs regardless, and the exporter
just stops exporting `kube_secret_*` / `kube_configmap_*`.

The container runs nonroot on a read-only root filesystem with all capabilities
dropped and no volumes.

## Configuration examples

Restrict collection to two namespaces and a few kinds — the usual answer when the
exporter's memory grows with a large cluster:

```yaml
extraArgs:
  - "--namespaces=team-a,team-b"
  - "--resources=pods,deployments,statefulsets,jobs"
```

Opt object labels into the metrics as `label_*` series:

```yaml
extraArgs:
  - "--metric-labels-allowlist=pods=[app,team],deployments=[app]"
```

Shard a very large cluster across three releases (each one a separate `helm install`):

```yaml
# release ksm-0
extraArgs: ["--shard=0", "--total-shards=3"]
```

Let a Prometheus in another namespace scrape it while keeping the policy closed:

```yaml
networkPolicy:
  extraFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
```

## Uninstall

```bash
helm uninstall ksm
```

Nothing persists — the exporter is stateless and holds no PVCs. The cluster-scoped
ClusterRole/ClusterRoleBinding are release-owned and go with it.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by
digest. The metrics endpoint is unauthenticated and describes every workload in the
cluster by name, so the NetworkPolicy is the trust boundary — keep
`allowExternal: false` and add explicit peers rather than exposing it.

The umbrella `observability-stack` and `lgtm-stack` charts already deploy their own
kube-state-metrics. Install this chart when you run your own Prometheus and want the
exporter on its own; do not install both into the same scrape target set.

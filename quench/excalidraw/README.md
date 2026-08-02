# Quenchworks Excalidraw

Hardened, self-hosted [Excalidraw](https://github.com/excalidraw/excalidraw)
virtual whiteboard for sketching hand-drawn-style diagrams, served as a static
SPA by nginx on a minimal, nonroot, 0-CVE image built from source, cosign-signed
and pinned by digest. This is the static, no-backend build: drawings live in the
browser's local storage — there is no account, database, or server-side state.

## Install

```bash
helm install board oci://ghcr.io/quenchworks/charts/excalidraw
```

nginx serves the app nonroot on container port 8080; the Service exposes HTTP 80.
Open it over a port-forward:

```bash
kubectl port-forward svc/board-excalidraw 8080:80
# visit http://127.0.0.1:8080
```

Turn on CPU autoscaling for spiky read traffic:

```bash
helm install board oci://ghcr.io/quenchworks/charts/excalidraw \
  --set autoscaling.enabled=true \
  --set autoscaling.maxReplicas=8
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/excalidraw \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/excalidraw --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/excalidraw` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `resources.requests` | `cpu 25m / mem 32Mi` | |
| `resources.limits` | `cpu 250m / mem 128Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `80` | Service maps 80 → container 8080. |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
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

A stateless Deployment runs nginx serving the pre-built Excalidraw SPA on
container port `8080` (nonroot). The Service maps port 80 to the container's
`http` port. Because the app is a static bundle with no backend, the workload
scales horizontally with no coordination — enable `autoscaling` (HPA on CPU) or
raise `replicaCount`. Liveness and readiness both `httpGet /` (a 200 means the
SPA is being served). The container runs on a read-only root filesystem; nginx
writes its pid and temp paths under a writable `/tmp` emptyDir, which is the only
writable mount. There is no persistence. Expose it beyond the cluster with your
own Ingress or a `LoadBalancer` service.

## Configuration examples

Front it with a LoadBalancer:

```yaml
service:
  type: LoadBalancer
  port: 80
```

Autoscale and spread across nodes (the last two keys flow through
`quench-common`):

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: excalidraw
```

## Uninstall

```bash
helm uninstall board
```

Nothing persists — the workload is stateless and holds no PVCs or Secrets.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. This is the offline/no-backend build of Excalidraw — for
real-time collaboration you would run the separate Excalidraw room/storage
services, which this chart does not deploy.

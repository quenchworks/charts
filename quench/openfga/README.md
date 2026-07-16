# Quenchworks OpenFGA

Hardened [OpenFGA](https://github.com/openfga/openfga), the CNCF fine-grained
authorization service (Google Zanzibar-style ReBAC) exposing HTTP and gRPC APIs,
on a minimal, nonroot, 0-CVE image built from source. It runs as `openfga run`
on a read-only root filesystem with all capabilities dropped, serving the HTTP
API on port 8080 and gRPC on port 8081. The image is cosign-signed (keyless /
Sigstore) and the chart pins it by the signed digest, never a tag.

## Install

```bash
helm install authz oci://ghcr.io/quenchworks/charts/openfga
```

The default in-memory datastore boots stateless with no database. For
production, point OpenFGA at a shared SQL datastore and keep the credentials in
a Secret:

```bash
helm install authz oci://ghcr.io/quenchworks/charts/openfga \
  --set datastore.engine=postgres \
  --set extraEnvVarsSecret=openfga-db
```

The server runs nonroot on container port 8080 (HTTP) and 8081 (gRPC); the
Service exposes both. Check health over a port-forward:

```bash
kubectl port-forward svc/authz-openfga 8080:8080
curl http://127.0.0.1:8080/healthz
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/openfga \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/openfga --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/openfga` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment. Keep at `1` with the in-memory datastore. |
| `datastore.engine` | `memory` | `memory`, `postgres`, or `mysql`. |
| `datastore.uri` | `""` | DB connection URI. Prefer a Secret via `extraEnvVarsSecret` (`OPENFGA_DATASTORE_URI`). |
| `playground.enabled` | `false` | Bundled developer playground (port 3000), unauthenticated — local use only. |
| `extraArgs` | `[]` | Extra flags appended to the `openfga run` command. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.httpPort` | `8080` | HTTP API. |
| `service.grpcPort` | `8081` | gRPC API. |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). Only meaningful with a shared datastore. |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy): `podLabels`,
`podAnnotations`, `nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `priorityClassName`, `schedulerName`,
`terminationGracePeriodSeconds`, `updateStrategy`, `extraEnvVars`,
`extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`, `extraVolumeMounts`,
`initContainers`, `sidecars`, `lifecycleHooks`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

A stateless Deployment runs the server via `openfga run` behind a ClusterIP
Service. The container serves the **HTTP API on 8080** and the **gRPC API on
8081**; the Service maps both to the same ports.

With the default `datastore.engine=memory` OpenFGA boots with no database. That
store is per-pod and lost on restart, and it is not shared across replicas — so
keep `replicaCount` at `1` with the in-memory datastore. Setting
`datastore.engine` to `postgres` or `mysql` and pointing at a shared database is
what makes it safe to raise `replicaCount` or enable `autoscaling` (HPA on CPU).
Leave `datastore.uri` empty and wire `OPENFGA_DATASTORE_URI` (and any
`OPENFGA_DATASTORE_*` tuning) through `extraEnvVars` / `extraEnvVarsSecret` so
credentials stay out of values. Run `openfga migrate` against a fresh SQL
database before first start.

The bundled developer playground (port 3000) is disabled by default: it is
unauthenticated and intended only for local experimentation. The container runs
nonroot on a read-only root filesystem with all capabilities dropped.

## Configuration examples

Production Postgres backend, credentials from an existing Secret, scaled out:

```yaml
datastore:
  engine: postgres
replicaCount: 3
extraEnvVarsSecret: openfga-db   # provides OPENFGA_DATASTORE_URI
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

Add server flags, e.g. structured logs and a request timeout:

```yaml
extraArgs:
  - "--log-format=json"
  - "--request-timeout=3s"
```

## Uninstall

```bash
helm uninstall authz
```

Nothing persists in-cluster — the workload is stateless and holds no PVCs. An
external SQL datastore, if configured, is unaffected.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. The in-memory datastore is single-node only; a shared SQL
datastore is required before scaling past one replica. OpenFGA is licensed
Apache-2.0.

# Quenchworks FerretDB

Hardened [FerretDB](https://www.ferretdb.com/) on a minimal, nonroot, 0-CVE
image pinned by digest and cosign-signed (keyless / Sigstore). FerretDB speaks
the MongoDB wire protocol and stores data in PostgreSQL with the DocumentDB
extension, so it is a stateless proxy: this chart runs a Deployment that scales
behind the Service. It needs a DocumentDB-extended PostgreSQL backend, the
companion [postgres-documentdb](https://ghcr.io/quenchworks/charts/postgres-documentdb)
chart or any equivalent.

## Install

Deploy the backend, then point FerretDB at it:

```bash
helm install docdb oci://ghcr.io/quenchworks/charts/postgres-documentdb \
  --set auth.password='change-me'

helm install fdb oci://ghcr.io/quenchworks/charts/ferretdb \
  --set backend.url='postgres://postgres:change-me@docdb-postgres-documentdb:5432/postgres'
```

Then connect with any MongoDB client:

```bash
mongosh 'mongodb://fdb-ferretdb:27017/'
```

You can instead keep the URL in your own Secret:

```bash
helm install fdb oci://ghcr.io/quenchworks/charts/ferretdb \
  --set backend.existingSecret=my-pg --set backend.existingSecretUrlKey=url
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ferretdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/ferretdb --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ferretdb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `backend.url` | `""` | Full `postgres://` URL to the DocumentDB-extended PostgreSQL. Stored in a Secret, read via `FERRETDB_POSTGRESQL_URL_FILE`. |
| `backend.existingSecret` | `""` | Use a Secret you manage instead of `backend.url`. |
| `backend.existingSecretUrlKey` | `postgresql-url` | Key in that Secret holding the URL. |
| `ferretdb.auth` | `true` | Authenticate clients against the backend PostgreSQL roles. |
| `ferretdb.extraArgs` | `[]` | Extra FerretDB flags. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 500m / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `27017` | MongoDB wire protocol. |
| `service.debugPort` | `8088` | HTTP metrics + `/debug/livez`, `/debug/readyz` (probes). |
| `autoscaling.enabled` | `false` | HPA on CPU (the proxy is stateless). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

FerretDB holds no state of its own, so the chart runs it as a stateless
Deployment. It serves the MongoDB wire protocol on port `27017` and translates
each operation into SQL against the DocumentDB-extended PostgreSQL backend, so
all durable data lives in that PostgreSQL instance, not in the pod. The backend
URL comes from a Secret (either the chart's own, rendered from `backend.url`, or
one you manage via `backend.existingSecret`) and FerretDB reads it from
`FERRETDB_POSTGRESQL_URL_FILE` rather than an environment variable. A second
port, `8088`, carries Prometheus metrics and the `/debug/livez` and
`/debug/readyz` probe endpoints.

Because the proxy is stateless, it scales horizontally with no coordination:
raise `replicaCount` or enable `autoscaling` (HPA on CPU). The container runs
nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The only mounts are the read-only backend-URL Secret and an
`emptyDir` at `/state`.

## Configuration examples

Point at a backend and turn off client auth (dev only):

```yaml
backend:
  url: postgres://postgres:change-me@docdb-postgres-documentdb:5432/postgres
ferretdb:
  auth: false
```

Read the URL from a Secret you manage and scale on CPU:

```yaml
backend:
  existingSecret: my-pg
  existingSecretUrlKey: url
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
```

## Uninstall

```bash
helm uninstall fdb
```

FerretDB holds no PVCs, so nothing persists on its side. Data lives in the
PostgreSQL backend; uninstall that release (and its PVCs) separately if you want
it gone.

## Notes

Provide exactly one of `backend.url` or `backend.existingSecret`. The chart
depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot on
a read-only root filesystem with all capabilities dropped, reachable only inside
the cluster by default (the NetworkPolicy restricts ingress to the release
namespace), and the image is pinned by digest.

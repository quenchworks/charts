# Quenchworks PostgreSQL + DocumentDB

Hardened PostgreSQL 17 carrying the open **DocumentDB** extension, which adds
BSON document storage and queries on top of Postgres — the backend
[FerretDB](https://www.ferretdb.com/) v2 needs to serve the MongoDB wire
protocol. On first boot the image runs `initdb`, preloads `pg_cron` +
`documentdb`, and runs `CREATE EXTENSION documentdb CASCADE` (pulling in
`documentdb_core`, `pg_cron`, `pgvector`, `postgis`, `rum`). This chart is the
data tier; point FerretDB at it with the
[ferretdb chart](https://ghcr.io/quenchworks/charts/ferretdb) or your own
`FERRETDB_POSTGRESQL_URL`. Runs on a minimal, nonroot (uid 1001), 0-CVE image on
a read-only root filesystem with all capabilities dropped. The image is
cosign-signed (keyless / Sigstore) and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install docdb oci://ghcr.io/quenchworks/charts/postgres-documentdb \
  --set auth.password='change-me'
```

A superuser password is generated into a Secret if you do not set one. The
`documentdb` extension is created in the `postgres` database (which is also
`pg_cron`'s `cron.database_name`), so connect there. Size the data volume and
pick a storage class:

```bash
helm install docdb oci://ghcr.io/quenchworks/charts/postgres-documentdb \
  --set auth.password='change-me' \
  --set primary.persistence.size=20Gi \
  --set primary.persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgres-documentdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/postgres-documentdb \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/postgres-documentdb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `auth.enabled` | `true` | A superuser password is required to initialize. |
| `auth.username` | `postgres` | Superuser created by initdb. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional extra database created on init; empty means just the default. |
| `auth.existingSecret` | `""` | Use an existing Secret instead of the generated one. |
| `auth.existingSecretPasswordKey` | `postgres-password` | Key in `existingSecret` holding the password. |
| `primary.persistence.enabled` | `true` | 8Gi PVC per replica via a `volumeClaimTemplate`; PGDATA lives in a subdir of it. When `false`, uses an `emptyDir` (data is lost on restart). |
| `primary.persistence.size` | `8Gi` | Requested volume size. |
| `primary.persistence.storageClass` | `""` (commented) | Default class if unset. |
| `primary.persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `primary.persistence.annotations` | `{}` | Annotations on the PVC template. |
| `primary.persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `primary.persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `primary.shmVolume.enabled` | `true` | Memory-backed `/dev/shm` so parallel queries do not fail. |
| `primary.resources.requests` | `cpu 250m / mem 256Mi` | |
| `primary.resources.limits` | `cpu 1 / mem 1Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `5432` | PostgreSQL wire protocol port. |
| `metrics.enabled` | `false` | Hardened `postgres-exporter` sidecar. |
| `metrics.image.repository` | `ghcr.io/quenchworks/images/postgres-exporter` | |
| `metrics.image.digest` | (CI-written) | Required when metrics are on. Pinned by digest. |
| `metrics.port` | `9187` | Exporter scrape port. |
| `metrics.resources.requests` | `cpu 50m / mem 32Mi` | |
| `metrics.resources.limits` | `cpu 100m / mem 64Mi` | |
| `metrics.serviceMonitor.enabled` | `false` | Prometheus Operator `ServiceMonitor`. |
| `metrics.serviceMonitor.interval` | `30s` | Scrape interval. |
| `metrics.prometheusRule.enabled` | `false` | Ship a `PrometheusRule`. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

The database runs as a **StatefulSet** (`replicas: 1`) behind a headless
service, so the primary keeps a stable network identity and its own volume. The
container listens on port **5432** (`postgresql`); the Service maps the same
port. `PGDATA` is `/var/lib/postgresql/data/pgdata` — a subdirectory of the
mounted volume, so initdb owns a clean directory and avoids `lost+found` and
mount-point ownership issues.

With `primary.persistence.enabled=true` (and no `existingClaim`) the chart
provisions one PVC via a `volumeClaimTemplate` mounted at
`/var/lib/postgresql/data`; set `existingClaim` to bind your own PVC, or disable
persistence to fall back to an `emptyDir` that does not survive a restart. Three
more mounts are `emptyDir`: the socket dir (`/var/run/postgresql`), `/tmp`, and —
when `primary.shmVolume.enabled` — a memory-backed `/dev/shm` for parallel query
workspace.

Probes: a TCP liveness check on the PostgreSQL port, and a readiness check that
runs `pg_isready` against the local socket as the configured superuser. The
password is delivered from a Secret through `POSTGRES_PASSWORD` / `PGPASSWORD`;
`auth.username` sets `POSTGRES_USER`, and `auth.database`, if set, creates an
extra database via `POSTGRES_DB`.

When `metrics.enabled`, a hardened `postgres-exporter` sidecar runs alongside
the server, scraping `localhost:5432/postgres` with the same credentials and
exposing metrics on port `9187`; optional `ServiceMonitor` and `PrometheusRule`
wire it into the Prometheus Operator.

## Configuration examples

Larger volume on a named storage class, using an existing password Secret:

```yaml
auth:
  existingSecret: my-pg-secret
  existingSecretPasswordKey: postgres-password
primary:
  persistence:
    enabled: true
    size: 50Gi
    storageClass: fast-ssd
  resources:
    requests: { cpu: "1", memory: 1Gi }
    limits: { cpu: "2", memory: 2Gi }
```

Turn on Prometheus metrics and a ServiceMonitor:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## Uninstall

```bash
helm uninstall docdb
```

PVCs provisioned by the `volumeClaimTemplate` are retained by Kubernetes on
uninstall — delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=docdb
```

## Notes

Single primary — streaming replication is a tracked follow-up. DocumentDB lives
in the `postgres` database. PostGIS is built without raster (no GDAL), since
DocumentDB's geospatial path needs only GEOS/PROJ. The local Unix socket trusts
in-container connections (so DocumentDB's pg_cron index builder works); TCP
authentication is scram-sha-256. Every container runs as nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

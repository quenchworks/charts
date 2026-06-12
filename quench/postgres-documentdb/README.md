# Quenchworks PostgreSQL + DocumentDB

Hardened PostgreSQL 17 carrying the **DocumentDB** extension — the backend
[FerretDB](https://www.ferretdb.com/) v2 needs to serve the MongoDB wire protocol.
On a minimal, nonroot, 0-CVE image pinned by digest. On first boot the image runs
`initdb`, preloads `pg_cron` + `documentdb`, and runs `CREATE EXTENSION documentdb
CASCADE` (pulling in `documentdb_core`, `pg_cron`, `pgvector`, `postgis`, `rum`).

This chart is the data tier; point FerretDB at it with the
[ferretdb chart](https://ghcr.io/quenchworks/charts/ferretdb) or your own
`FERRETDB_POSTGRESQL_URL`.

## Install

```bash
helm install docdb oci://ghcr.io/quenchworks/charts/postgres-documentdb \
  --set auth.password='change-me'
```

A superuser password is generated into a Secret if you do not set one. The
`documentdb` extension is created in the `postgres` database (which is also
`pg_cron`'s `cron.database_name`), so connect there.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgres-documentdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/postgres-documentdb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.enabled` | `true` | A superuser password is required to initialize. |
| `auth.username` | `postgres` | Superuser created by initdb. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC; PGDATA lives in a subdir of it. |
| `primary.shmVolume.enabled` | `true` | Memory-backed `/dev/shm` for parallel queries. |
| `service.port` | `5432` | |
| `metrics.enabled` | `false` | Hardened `postgres-exporter` sidecar. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. PGDATA, the socket dir, `/tmp`, and `/dev/shm` are the only writable mounts.
The local Unix socket trusts in-container connections (so DocumentDB's pg_cron index
builder works); TCP authentication is scram-sha-256.

## Notes

Single primary. DocumentDB lives in the `postgres` database. PostGIS is built
without raster (no GDAL), since DocumentDB's geospatial path needs only GEOS/PROJ.
Streaming replication is a tracked follow-up. Depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

# Nessie

[Project Nessie](https://projectnessie.org) is a transactional catalog for data lakehouse
tables. It adds Git-like branches, tags and commits over Iceberg table metadata, and
serves the Iceberg REST catalog API. This chart runs it on the QuenchWorks nessie image.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install nessie oci://ghcr.io/quenchworks/charts/nessie --set versionStore.type=ROCKSDB
kubectl port-forward svc/nessie 19120:19120
curl http://127.0.0.1:19120/api/v2/config
```

Spark, Trino, Flink and other Iceberg clients point at `http://nessie:19120/iceberg`
(REST catalog) or `http://nessie:19120/api/v2` (Nessie catalog).

## Version store

| `versionStore.type` | Where commits live | Replicas |
|---|---|---|
| `IN_MEMORY` (default) | the pod's memory, lost on restart | any |
| `ROCKSDB` | a RocksDB on a PVC (`rocksdb.persistence`), kept on uninstall | 1, recreated on upgrade |
| `JDBC2` | PostgreSQL, MariaDB or MySQL (`jdbc`) | `replicas` |

For JDBC2, set `jdbc.url` (for example `jdbc:postgresql://pg.data.svc:5432/nessie`),
`jdbc.datasource`, and `jdbc.existingSecret` holding the username and password.

## Security

Nessie has no authentication by default: anyone who reaches the Service can create
branches and commit. Keep the Service internal, or enable OIDC through `extraEnvVars`
(`NESSIE_SERVER_AUTHENTICATION_ENABLED=true` and the `QUARKUS_OIDC_*` settings).

## Values

| Key | Default | Meaning |
|---|---|---|
| `versionStore.type` | `IN_MEMORY` | `IN_MEMORY`, `ROCKSDB` or `JDBC2` |
| `rocksdb.persistence.size` | `8Gi` | PVC size for ROCKSDB |
| `rocksdb.persistence.existingClaim` | `""` | use an existing PVC |
| `jdbc.url` / `jdbc.existingSecret` | `""` | the JDBC2 database |
| `replicas` | `1` | ignored for ROCKSDB |
| `javaOpts` | `-XX:MaxRAMPercentage=75` | JVM flags |
| `extraEnvVars` | `[]` | any other Nessie or Quarkus setting as an env var |
| `service.port` | `19120` | API port |

Pods run with a read-only root filesystem and all capabilities dropped. Health and
metrics are on 9000 (`/q/health`, `/q/metrics`), which the probes use.

The release gate installs the chart on kind with the RocksDB store, creates a branch and
a commit through the API, deletes the pod, and requires both to be there after the
restart.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

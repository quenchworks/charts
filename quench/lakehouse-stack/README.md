# Quenchworks lakehouse-stack

An open lakehouse in one install, from QuenchWorks images (nonroot, 0 fixable
CVEs, pinned by digest, cosign-signed):

| Component | Chart | Role |
|---|---|---|
| Trino | `trino` | distributed SQL over the tables |
| Nessie | `nessie` | the Apache Iceberg catalog, with Git-like branches |
| SeaweedFS | `seaweedfs` | S3 storage for the table data |

The stack generates the S3 keys (Secret `lake-s3`), gives them to SeaweedFS and
Trino, creates the `lake` bucket with a Job, and configures a Trino catalog named
`lake` that writes Iceberg tables to `s3://lake/warehouse` through Nessie.

## Install

```bash
helm install lake oci://ghcr.io/quenchworks/charts/lakehouse-stack
kubectl port-forward svc/lake-trino 8080:8080
```

Then, from any Trino client (user name of your choice):

```sql
CREATE SCHEMA lake.demo;
CREATE TABLE lake.demo.events (id bigint, kind varchar);
INSERT INTO lake.demo.events VALUES (1, 'signup');
SELECT * FROM lake.demo.events;
```

Names are fixed (`lake-trino`, `lake-nessie`, `lake-seaweedfs`) and the bucket is
`lake`, so run one stack per namespace.

## Values

| Key | Default | Notes |
|---|---|---|
| `trino.catalogs.lake` | Iceberg on Nessie + S3 | add more catalogs beside it under `trino.catalogs` |
| `nessie.versionStore.type` | `ROCKSDB` | on a PVC; `JDBC` for PostgreSQL |
| `seaweedfs.persistence.size` | `8Gi` | the table data |
| `bucketJob.enabled` | `true` | creates the `lake` bucket |

## Notes

- Trino has no authentication in this configuration: anyone who reaches port
  8080 can query every catalog. Keep it cluster-internal or put an
  authenticating proxy in front.
- Nessie runs without authentication; its API is reachable inside the cluster.

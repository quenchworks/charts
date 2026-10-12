# Apache Polaris

[Apache Polaris](https://polaris.apache.org) is an open REST catalog for Apache Iceberg. It
serves the Iceberg REST API to Spark, Trino, Flink and other engines, manages catalogs,
principals and role-based grants through its management API, and vends short-lived storage
credentials for S3, GCS and Azure. This chart runs it on the QuenchWorks apache-polaris image.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install polaris oci://ghcr.io/quenchworks/charts/apache-polaris
kubectl port-forward svc/polaris-apache-polaris 8181:8181
SECRET=$(kubectl get secret polaris-apache-polaris -o jsonpath='{.data.client-secret}' | base64 -d)
curl http://127.0.0.1:8181/api/catalog/v1/oauth/tokens -d grant_type=client_credentials \
  -d client_id=root -d client_secret="$SECRET" -d scope=PRINCIPAL_ROLE:ALL
```

Engines use `http://<release>-apache-polaris:8181/api/catalog` as the Iceberg REST URI.

## Metastore

| `persistence.type` | Where state lives | Replicas |
|---|---|---|
| `in-memory` (default) | the pod's memory, lost on restart | 1 |
| `relational-jdbc` | PostgreSQL: bundled (`postgresql.enabled=true`) or `externalDatabase` | `replicas` |

PostgreSQL is upstream's production path. With `relational-jdbc` an initContainer runs the
Polaris admin tool `bootstrap` before the server starts: it creates the tables in
`jdbcSchema` (default `public`) and the realm's root principal, and skips a realm that is
already bootstrapped, so upgrades and restarts are safe. For an external database set
`externalDatabase.url` (for example `jdbc:postgresql://pg.data.svc:5432/polaris`) and
`externalDatabase.existingSecret` holding the username and password.

```sh
helm install polaris oci://ghcr.io/quenchworks/charts/apache-polaris \
  --set persistence.type=relational-jdbc --set postgresql.enabled=true
```

## Credentials

The realm (`auth.realm`, default `POLARIS`) gets one root principal, `auth.clientId`
(default `root`). Its client secret and the key that signs access tokens are generated into
the chart's Secret (`client-id`, `client-secret`, `token-key`) and kept across upgrades. Set
`auth.clientSecret`, or `auth.existingSecret` with those three keys, to choose them. Every
replica shares the token key, so a token from one pod is valid on all of them.

## Values

| Key | Default | Meaning |
|---|---|---|
| `persistence.type` | `in-memory` | `in-memory` or `relational-jdbc` |
| `auth.realm` / `auth.clientId` | `POLARIS` / `root` | realm and root principal |
| `auth.clientSecret` / `auth.existingSecret` | `""` | root secret, generated when empty |
| `postgresql.enabled` | `false` | bundle the QuenchWorks postgresql chart |
| `externalDatabase.url` / `.existingSecret` | `""` | an existing PostgreSQL |
| `jdbcSchema` | `public` | schema holding the Polaris tables (must exist) |
| `properties` | `{}` | extra Polaris or Quarkus settings, rendered into `config/application.properties` |
| `replicas` | `1` | ignored for in-memory |
| `javaOpts` | `-XX:MaxRAMPercentage=75` | JVM flags |
| `extraEnvVars` | `[]` | any other setting as an env var |
| `service.port` / `service.managementPort` | `8181` / `8182` | API and health/metrics ports |

Storage types default to upstream's `S3`, `GCS` and `AZURE`. `FILE` storage is refused by
Polaris outside tests; enabling it takes `polaris.features."SUPPORTED_CATALOG_STORAGE_TYPES"`,
`polaris.features."ALLOW_INSECURE_STORAGE_TYPES"` and `polaris.readiness.ignore-severe-issues`
in `properties`.

Pods run with a read-only root filesystem and all capabilities dropped. Health and metrics
are on 8182 (`/q/health`, `/q/metrics`), which the probes use.

The release gate installs the chart on kind with the bundled PostgreSQL, gets a token with
the generated root credentials, creates a catalog and a namespace, lists both, deletes the
pod, and lists them again after the restart.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

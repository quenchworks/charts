# trino

Trino, the distributed SQL query engine, as one coordinator and a set of workers,
on the QuenchWorks image: hardened, nonroot, 0-CVE, pinned by digest and
cosign-signed.

## Install

```sh
helm install sql oci://ghcr.io/quenchworks/charts/trino
kubectl port-forward svc/sql-trino 8080:8080
```

Point any Trino client (CLI, JDBC, Python `trino`) at `http://sql-trino:8080`.

## Topology

- **Coordinator**: always one pod; Trino has no coordinator failover. The Service
  selects it.
- **Workers**: `worker.replicas` pods (default 2). They find the coordinator through
  `discovery.uri`, the Service. With `worker.replicas: 0` the coordinator runs tasks
  itself.
- **Memory**: each JVM takes `jvm.ramPercentage` (75) of its pod's memory limit as
  heap, so size queries through the `resources.limits` of each role. Add
  `query.max-memory*` under `config` to cap them.

## Catalogs

Each `catalogs.<name>` becomes `etc/catalog/<name>.properties` on every node. The
image ships the **jmx, memory, tpcds, tpch and postgresql** connectors; the default
values enable tpch and memory. Keep credentials out of values with `${ENV:NAME}`:

```yaml
catalogs:
  pg: |
    connector.name=postgresql
    connection-url=jdbc:postgresql://db:5432/app
    connection-user=${ENV:PG_USER}
    connection-password=${ENV:PG_PASSWORD}
extraEnvVarsSecret: pg-credentials   # keys PG_USER, PG_PASSWORD
```

## What the image leaves out

Fault-tolerant execution and the spooling client protocol need the
`exchange-filesystem` and `spooling-filesystem` plugins, which the image drops (they
carried every CVE finding in the upstream core). Other connectors (Hive, Iceberg,
Delta Lake, and so on) are not in the image.

## Security

Authentication is off by default. Before exposing the coordinator, configure it
under `config` (for example `http-server.authentication.type: PASSWORD` with a
password file, or OAUTH2) together with TLS.

## Values

| Key | Default | Meaning |
|---|---|---|
| `worker.replicas` | `2` | worker pods; 0 for a single node |
| `coordinator.resources`, `worker.resources` | 2Gi limits | per-role resources; the heap follows the memory limit |
| `jvm.ramPercentage` | `75` | heap share of the memory limit |
| `jvm.extraOptions` | `[]` | extra JVM flags |
| `config` | `{}` | extra config.properties entries on every node |
| `catalogs` | tpch, memory | catalog files |
| `logLevels` | `{}` | log.properties |
| `networkPolicy.allowExternal` | `true` | admit clients from other namespaces |

## Release gate

On kind, the gate installs one coordinator and one worker, waits until both appear
in `system.runtime.nodes`, then runs a tpch join across the cluster and a memory
catalog CREATE and SELECT.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Dagster

[Dagster](https://dagster.io) is an asset-oriented orchestrator for data and ML
pipelines. This chart runs the Dagster **webserver** (UI and GraphQL on 3000) and the
**daemon** (schedules, sensors, the run queue) on the QuenchWorks dagster image, with the
instance's run, event-log and schedule storage in PostgreSQL, so every process shares it.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install dagster oci://ghcr.io/quenchworks/charts/dagster
kubectl port-forward svc/dagster-webserver 3000:3000
```

## Your code

Dagster loads user code from **code locations**: gRPC servers running your definitions.
Build them from the same image and point the chart at them:

```dockerfile
FROM ghcr.io/quenchworks/images/dagster:1.13.24
COPY my_pipelines/ /opt/code/my_pipelines/
# run: dagster code-server start -h 0.0.0.0 -p 4000 -m my_pipelines
```

```yaml
codeLocations:
  - name: my-pipelines
    host: my-pipelines-code.data.svc.cluster.local
    port: 4000
```

`example.enabled=true` deploys a one-asset code location from the dagster image itself.

## Storage

| Mode | Values |
|---|---|
| bundled (default) | `postgresql.enabled=true`; the QuenchWorks postgresql chart, password generated into `<release>-postgresql` |
| external | `postgresql.enabled=false`, `externalDatabase.host/port/database/username`, and `externalDatabase.existingSecret` + `existingSecretPasswordKey` |

SQLite is not an option here: the webserver and the daemon run in separate pods and must
share storage.

## Values

| Key | Default | Meaning |
|---|---|---|
| `codeLocations` | `[]` | gRPC code servers to load |
| `example.enabled` | `false` | the bundled one-asset example location |
| `runCoordinator.maxConcurrentRuns` | `""` | queue limit for the QueuedRunCoordinator |
| `instanceConfig` | `{}` | extra top-level `dagster.yaml` keys (run_launcher, compute_logs, ...) |
| `daemon.enabled` | `true` | run the daemon (schedules and sensors need it) |
| `webserver.replicas` | `1` | webserver pods |

Pods run with a read-only root filesystem, all capabilities dropped, and emptyDirs for
`DAGSTER_HOME` and `/tmp`; telemetry is disabled. Config changes roll the pods.

The release gate installs the chart on kind with the bundled PostgreSQL and the example
location, and requires the webserver to load the location over gRPC and the daemon to
report healthy through the shared PostgreSQL storage.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

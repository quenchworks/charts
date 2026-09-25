# Prefect

[Prefect](https://www.prefect.io) is a Python-native workflow orchestrator. This chart
runs the Prefect **server** (API and UI on 4200, plus the background services that
schedule and track runs) on the QuenchWorks prefect image, with its state in
PostgreSQL, and optionally a **process worker** that polls a work pool and runs flows.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install prefect oci://ghcr.io/quenchworks/charts/prefect
kubectl port-forward svc/prefect-server 4200:4200
export PREFECT_API_URL=http://127.0.0.1:4200/api
```

## Your flows

A process worker runs flow code in its own pod, so the code must be importable from the
worker image. Build it FROM the prefect image and point the worker at it:

```dockerfile
FROM ghcr.io/quenchworks/images/prefect:3.8.6
COPY flows/ /opt/flows/
```

```yaml
worker:
  enabled: true
  pool: default
  image:
    repository: registry.example.com/my-flows
    digest: sha256:...
```

The worker creates its work pool on first start.

## Storage

| Mode | Values |
|---|---|
| bundled (default) | `postgresql.enabled=true`; the QuenchWorks postgresql chart, password generated into `<release>-postgresql` |
| external | `postgresql.enabled=false`, `externalDatabase.host/port/database/username`, and `externalDatabase.existingSecret` + `existingSecretPasswordKey` |

The chart passes the database as discrete settings (`PREFECT_SERVER_DATABASE_*`), so
the password is never part of a connection URL.

## Values

| Key | Default | Meaning |
|---|---|---|
| `server.replicas` | `1` | server pods; each also runs the background services |
| `ui.enabled` | `true` | serve the UI |
| `ui.apiUrl` | `http://127.0.0.1:4200/api` | API URL the browser calls; set your ingress URL when exposing the UI |
| `worker.enabled` | `false` | run a process worker |
| `worker.pool` | `default` | work pool the worker polls |
| `worker.image` | `{}` | worker image override (repository + digest) |

Pods run with a read-only root filesystem, all capabilities dropped, and emptyDirs for
`PREFECT_HOME` and `/tmp`; usage analytics are disabled. Every process waits for its
dependency (PostgreSQL for the server, the server for the worker) in an init container.

The release gate installs the chart on kind with the bundled PostgreSQL and the worker,
and requires the API to report healthy and the right version, the UI to be served, the
worker to register with its pool, and a flow run to complete against the server.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

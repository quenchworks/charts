# Quenchworks OpenFGA

Hardened [OpenFGA](https://github.com/openfga/openfga) on a minimal, nonroot,
0-CVE image, built from source and pinned by digest. OpenFGA is a CNCF
fine-grained authorization service (Google Zanzibar-style ReBAC) exposing HTTP
and gRPC APIs.

## Install

```sh
helm install authz oci://ghcr.io/quenchworks/charts/openfga
```

The server runs nonroot and serves the HTTP API on container port 8080 and the
gRPC API on 8081; the Service exposes both. Check health over a port-forward:

```sh
kubectl port-forward svc/authz-openfga 8080:8080
curl http://127.0.0.1:8080/healthz
```

## Configuration

OpenFGA runs as `openfga run`. By default it uses the in-memory datastore, so
it boots fully stateless with no database — state is lost on restart and is not
shared across replicas, so keep `replicaCount` at `1`.

For production, set `datastore.engine` to `postgres` or `mysql` and provide the
connection URI. Keep credentials out of values by leaving `datastore.uri` empty
and wiring `OPENFGA_DATASTORE_URI` (and any `OPENFGA_DATASTORE_*` tuning) via
`extraEnvVars` / `extraEnvVarsSecret`. Migrate the database (`openfga migrate`)
before first start; with a shared database you can raise `replicaCount` or
enable autoscaling.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/openfga` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment (in-memory datastore) |
| `datastore.engine` | `memory` | `memory`, `postgres`, or `mysql` |
| `datastore.uri` | `""` | DB connection URI (prefer a Secret via extraEnvVarsSecret) |
| `playground.enabled` | `false` | bundled dev playground (port 3000), unauthenticated |
| `extraArgs` | `[]` | appended to the `openfga run` command |
| `service.type` | `ClusterIP` | |
| `service.httpPort` | `8080` | HTTP API |
| `service.grpcPort` | `8081` | gRPC API |

# Quenchworks MLflow

Hardened [MLflow](https://mlflow.org/) Tracking Server — experiment tracking, the model
registry, and a REST/UI for ML metadata — on a minimal, nonroot, 0-CVE image pinned by
digest and cosign-signed. The server runs as uid `1001` on a read-only root filesystem
and serves its UI + REST API on port `5000`.

MLflow's tracking server is **stateless**: all durable state lives in an external
**PostgreSQL** backend store (experiments, runs, params, metrics, model registry) plus
an **artifact store** for logged files and models. This chart bundles the Quenchworks
PostgreSQL chart by default and provisions a PVC artifact store served through the
tracking server (`--serve-artifacts`). It can also point at an external database and/or
object-storage artifact root.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL + a PVC artifact store
helm install mlf oci://ghcr.io/quenchworks/charts/mlflow \
  --set postgresql.auth.password="ChangeMe"
```

The backend-store DSN is assembled inside a managed Secret and injected as
`MLFLOW_BACKEND_STORE_URI` — the DB password never appears in the pod's process
arguments.

## Connect

```bash
kubectl port-forward svc/mlf-mlflow 5000:5000
export MLFLOW_TRACKING_URI=http://localhost:5000
# UI: http://localhost:5000/
```

Health / API:

```bash
curl -fsS http://localhost:5000/health                           # serving
curl -fsS http://localhost:5000/api/2.0/mlflow/experiments/search # list experiments
```

## Backend store

By default the bundled Quenchworks PostgreSQL subchart is deployed. The bundled image
creates `postgresql.auth.username` as the superuser and only creates the application
database when it **differs** from the username, so the chart keeps `username`
(`mlflowuser`) and `database` (`mlflow`) distinct. Set `postgresql.auth.password` for a
deterministic install.

To use an external PostgreSQL, set `postgresql.enabled=false` and fill in
`externalDatabase.*` (or `externalDatabase.existingSecret` carrying `backend-store-uri`
and the password key).

## Artifact store

By default a `ReadWriteOnce` PVC is mounted at `/mnt/artifacts` and served through the
tracking server. For object storage, set `persistence.enabled=false`, point
`artifactRoot` at e.g. `s3://my-bucket/mlflow`, and supply credentials via
`extraEnvVars` (the image bundles `boto3`).

## Security

MLflow ships **no built-in authentication**. By default `networkPolicy.allowExternal`
is `false`, restricting ingress to the release namespace. Front the server with an
authenticating ingress/proxy and set `allowExternal=true` before exposing it.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/mlflow \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/mlflow --owner quenchworks`.

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/mlflow` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `replicaCount` | `1` | Tracking server replicas |
| `service.port` | `5000` | UI + REST API port |
| `persistence.enabled` | `true` | Provision the PVC artifact store |
| `persistence.size` | `10Gi` | Artifact PVC size |
| `persistence.mountPath` | `/mnt/artifacts` | Artifact mount path |
| `artifactRoot` | `""` | Artifact URI (defaults to `file://<mountPath>`) |
| `postgresql.enabled` | `true` | Deploy the bundled PostgreSQL backend store |
| `postgresql.auth.username` | `mlflowuser` | DB user (must differ from database) |
| `postgresql.auth.database` | `mlflow` | App database |
| `networkPolicy.allowExternal` | `false` | Allow ingress from outside the namespace |

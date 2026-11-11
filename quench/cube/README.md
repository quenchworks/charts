# Quenchworks Cube

Hardened [Cube](https://github.com/cube-js/cube), the semantic layer server: a data model over
your database, served as REST, GraphQL and a Postgres-protocol SQL API that BI tools connect to.
One Deployment serves the API on port 4000 and the SQL API on 15432.

The image is built from the upstream release tag: the npm server with the postgres, mysql and
clickhouse drivers on Node 24, and the native addon (which carries the SQL API) compiled from
source with cargo auditable, so the scanner sees every Rust crate in it. It runs as nonroot uid
1001, is CVE-gated (the build fails on any fixable CVE), and is cosign-signed and pinned by
digest. It does not include Cube Store.

## Install

```bash
helm install bi oci://ghcr.io/quenchworks/charts/cube \
  --set database.host=my-postgres --set database.name=analytics \
  --set database.user=cube --set database.existingSecret=my-postgres-secret \
  --set-file model.orders\\.yml=orders.yml
kubectl port-forward svc/bi-cube 4000:4000 15432:15432
```

Clients call the REST API with a JWT signed (HS256) by the API secret:

```bash
kubectl get secret bi-cube -o jsonpath='{.data.api-secret}' | base64 -d; echo
```

BI tools connect to the SQL API as `cube` with the generated password (key `sql-password`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cube \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/cube@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/cube` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `1` | API pods; stateless. |
| `database.type` | `postgres` | `postgres`, `mysql` or `clickhouse` (the drivers in the image). |
| `database.host` / `port` / `name` / `user` | `""` | Connection settings. |
| `database.existingSecret` / `existingSecretPasswordKey` | `""` / `password` | Secret holding the database password. |
| `database.password` | `""` | Plain password, stored in the chart's Secret (prefer `existingSecret`). |
| `database.ssl` | `false` | TLS to the database. |
| `auth.apiSecret` | `""` | JWT signing secret. Empty: generated and kept across upgrades. |
| `auth.existingSecret` | `""` | Secret with keys `api-secret` and `sql-password`. |
| `sqlApi.enabled` / `port` / `user` / `password` | `true` / `15432` / `cube` / `""` | Postgres-protocol SQL API; empty password is generated. |
| `cubestore.host` | `""` | Cube Store host for shared cache, queue and pre-aggregations. Empty: in-memory per pod. |
| `model` | `{}` | Data model files (file name to YAML), mounted at `/cube/conf/model`. |
| `service.type` / `service.port` | `ClusterIP` / `4000` | |
| `ingress.enabled` | `false` | Optional Ingress for the API. |
| `networkPolicy.enabled` / `networkPolicy.allowExternal` | `true` / `true` | Ingress to the API ports; `allowExternal=false` confines it to the namespace. |
| `resources` | 100m / 256Mi requests, 2 CPU / 1Gi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.
Any other Cube setting is a `CUBEJS_*` variable in `extraEnvVars`.

## Design

- **In-memory cache by default.** The image runs with `NODE_ENV=production`, where Cube expects a
  Cube Store and fails queries without one; the chart sets `CUBEJS_CACHE_AND_QUEUE_DRIVER=memory`
  unless `cubestore.host` is set.
- **Readiness is the database.** `/readyz` tests the database connection and the cache driver, so
  a pod is Ready only when Cube can query; `/livez` needs no database.
- **One mount per model file.** Each `model` key is a `subPath` mount: a whole-ConfigMap mount
  also exposes the kubelet's `..data` copies, which Cube's recursive loader reads as duplicate
  cubes. subPath mounts do not live-update, so the pod template carries a checksum of `model`
  and a change rolls the pods.
- **Read-only root filesystem.** The model is a ConfigMap; scratch space is an emptyDir at `/tmp`.
- **Secrets survive upgrades.** The generated API secret and SQL password are read back from the
  existing Secret, so an upgrade does not invalidate issued JWTs or BI connections.

Cube is Apache-2.0 licensed.

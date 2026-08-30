# Quenchworks PostgREST

Hardened [PostgREST](https://github.com/PostgREST/postgrest): a standalone server
that serves a RESTful API straight out of a PostgreSQL schema, with authorization
delegated to the database's own roles and row-level security. Runs as a stateless
Deployment on port 3000. Upstream's official prebuilt binary, hardened on a
minimal, nonroot, 0-CVE image that runs on a read-only root filesystem with all
capabilities dropped. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

PostgREST cannot start without a database, so the chart brings one:

```bash
helm install api oci://ghcr.io/quenchworks/charts/postgrest
```

That pulls the QuenchWorks `postgresql` subchart, builds the connection URI from
`postgresql.auth.*`, and stores it in a Secret as `PGRST_DB_URI`. **Change
`postgresql.auth.password` for anything real** — it is shared with the URI.

Against your own server instead:

```bash
helm install api oci://ghcr.io/quenchworks/charts/postgrest \
  --set postgresql.enabled=false \
  --set externalDatabase.host=db.internal \
  --set externalDatabase.user=authenticator \
  --set externalDatabase.password='<password>' \
  --set externalDatabase.database=appdb
```

Or hand it a URI you manage yourself, so no password passes through Helm values:

```bash
kubectl create secret generic postgrest-db \
  --from-literal=database-uri='postgres://authenticator:pw@db.internal:5432/appdb?sslmode=require'

helm install api oci://ghcr.io/quenchworks/charts/postgrest \
  --set postgresql.enabled=false \
  --set externalDatabase.existingSecret=postgrest-db
```

The URI is **always** a Secret — never a ConfigMap, never a command-line flag —
because it carries a password.

## Serving your first table

PostgREST creates nothing; it exposes what is already in the database. Create a
table and tell the running instance to reload its schema cache:

```bash
kubectl exec -i statefulset/api-postgresql -- \
  psql -h /var/run/postgresql -U postgres -d postgrest \
  -c "create table todos (id serial primary key, task text);" \
  -c "insert into todos (task) values ('write the chart');" \
  -c "notify pgrst, 'reload schema';"

kubectl port-forward svc/api-postgrest 3000:3000
curl http://127.0.0.1:3000/todos
```

That last call only returns rows if requests can authorize — see below.

## Authorization: `db.anonRole` and `jwt.secret`

PostgREST runs every request as a database role, so who may read what is a
question you answer with `GRANT` and row-level security, not with chart values.
Two knobs decide how a request gets a role:

- `db.anonRole` — the role used for **unauthenticated** requests. It is **empty by
  default**, which means no anonymous access at all: every request must present a
  JWT. Setting it hands anyone who can reach the Service exactly that role's
  privileges, so point it at a dedicated, narrowly-granted role. Never the table
  owner and never a superuser.
- `jwt.secret` (or `jwt.existingSecret`) — the key PostgREST verifies bearer
  tokens with, 32 characters minimum. Its `role` claim selects the database role
  for that request.

A read-only public API, for example:

```sql
create role web_anon nologin;
grant usage on schema public to web_anon;
grant select on todos to web_anon;
```

```yaml
db:
  anonRole: web_anon
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgrest \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/postgrest \
  --owner quenchworks
```

## Values

| Key                                          | Default                                | Notes                                                                                     |
| -------------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`                           | `ghcr.io/quenchworks/images/postgrest` |                                                                                           |
| `image.digest`                               | (CI-written)                           | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                           | `IfNotPresent`                         | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                               | `""`                                   | Override the chart name in resource names.                                                |
| `replicaCount`                               | `1`                                    | Stateless; scale freely (mind `db.pool` × replicas vs `max_connections`).                 |
| `postgresql.enabled`                         | `true`                                 | Bundle the QuenchWorks PostgreSQL subchart.                                               |
| `postgresql.auth.username`                   | `postgres`                             | Superuser; also the URI user.                                                             |
| `postgresql.auth.password`                   | `postgrest`                            | **Shared with `PGRST_DB_URI`. Override it.**                                              |
| `postgresql.auth.database`                   | `postgrest`                            | Database PostgREST connects to.                                                           |
| `postgresql.primary.persistence.*`           | `enabled: true`, `8Gi`                 | Passed through to the subchart.                                                           |
| `externalDatabase.host`                      | `""`                                   | Required when `postgresql.enabled=false`.                                                 |
| `externalDatabase.port`                      | `5432`                                 |                                                                                           |
| `externalDatabase.user`                      | `postgres`                             | The PostgREST *authenticator* role.                                                       |
| `externalDatabase.password`                  | `""`                                   | Rendered into the chart's Secret.                                                         |
| `externalDatabase.database`                  | `postgres`                             |                                                                                           |
| `externalDatabase.sslmode`                   | `require`                              | Appended to the URI.                                                                      |
| `externalDatabase.existingSecret`            | `""`                                   | A Secret already holding a full `postgres://` URI; nothing is templated.                  |
| `externalDatabase.existingSecretURIKey`      | `database-uri`                         | Key inside that Secret.                                                                   |
| `db.schemas`                                 | `public`                               | `PGRST_DB_SCHEMAS`, comma-separated.                                                      |
| `db.anonRole`                                | `""`                                   | Role for unauthenticated requests. Empty = **no anonymous access**.                       |
| `db.extraSearchPath`                         | `public`                               | `PGRST_DB_EXTRA_SEARCH_PATH`.                                                             |
| `db.pool`                                    | `10`                                   | Connections per replica.                                                                  |
| `jwt.secret`                                 | `""`                                   | JWT verification key, 32+ chars; stored in the chart's Secret.                            |
| `jwt.existingSecret`                         | `""`                                   | Take it from a Secret you manage instead.                                                 |
| `jwt.existingSecretKey`                      | `jwt-secret`                           | Key inside that Secret.                                                                   |
| `logLevel`                                   | `error`                                | `crit`, `error`, `warn`, `info`, `debug`.                                                 |
| `adminServer.enabled`                        | `true`                                 | Admin port serving `/live` and `/ready`, used by the probes. Not published by the Service.|
| `adminServer.port`                           | `3001`                                 |                                                                                           |
| `resources.requests`                         | `cpu 50m / mem 64Mi`                   | CPU / memory requests.                                                                    |
| `resources.limits`                           | `cpu 500m / mem 256Mi`                 | CPU / memory limits.                                                                      |
| `service.type`                               | `ClusterIP`                            | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.port`                               | `3000`                                 | REST API.                                                                                 |
| `autoscaling.enabled`                        | `false`                                | HPA on CPU (autoscaling/v2). Safe: PostgREST is stateless.                                |
| `autoscaling.minReplicas`                    | `1`                                    |                                                                                           |
| `autoscaling.maxReplicas`                    | `5`                                    | Watch `maxReplicas × db.pool` against the server's `max_connections`.                     |
| `autoscaling.targetCPUUtilizationPercentage` | `80`                                   |                                                                                           |
| `serviceAccount.create`                      | `true`                                 | Token automount is off.                                                                   |
| `serviceAccount.name`                        | `""`                                   | Use an existing ServiceAccount if set.                                                    |
| `serviceAccount.annotations`                 | `{}`                                   | Annotations on the ServiceAccount.                                                        |
| `rbac.create`                                | `false`                                | Minimal Role/RoleBinding.                                                                 |
| `networkPolicy.enabled`                      | `true`                                 | Restricts ingress.                                                                        |
| `networkPolicy.allowExternal`                | `false`                                | Namespace-only by default. Set `true`, or use `networkPolicy.extraFrom`, for wider access.|
| `podDisruptionBudget.enabled`                | `true`                                 |                                                                                           |
| `podDisruptionBudget.minAvailable`           | `1`                                    |                                                                                           |
| `ingress.enabled`                            | `false`                                | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`                          | `""`                                   | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`                        | `{}`                                   | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`                        | `null`                                 | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`                              | `[]`                                   | e.g. `[{host: api.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                                | `[]`                                   | Standard Ingress TLS list, e.g. `[{hosts: [api.example.com], secretName: api-tls}]`.      |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

PostgREST runs as a **Deployment** behind a **ClusterIP** Service on container
port `3000`. It is configured entirely through `PGRST_*` environment variables —
that is PostgREST's own configuration mechanism, so the chart wires the handful
that matter (`PGRST_DB_URI`, `PGRST_DB_SCHEMAS`, `PGRST_DB_ANON_ROLE`,
`PGRST_DB_EXTRA_SEARCH_PATH`, `PGRST_DB_POOL`, `PGRST_SERVER_PORT`,
`PGRST_ADMIN_SERVER_PORT`, `PGRST_LOG_LEVEL`, `PGRST_JWT_SECRET`) and leaves
everything else to `extraEnvVars` with its documented `PGRST_` name. There is no
config file and no ConfigMap: the two settings worth protecting are secrets, and
the rest are one env var each.

The **admin server** (port 3001, `adminServer.enabled`) exists so the probes have
something honest to ask. `/live` says the process is up; `/ready` says the
database connection is established and the schema cache is loaded — so a Ready
pod can actually answer queries. The API port has no such endpoint: `/` is the
OpenAPI document and is subject to the same authorization as everything else, so
probing it would fail on a locked-down instance. The admin port is deliberately
not published by the Service.

The pod mounts nothing: PostgREST is a single binary with a read-only root
filesystem and no local state. Scaling out is safe — each replica just opens its
own pool of `db.pool` connections, which is the number to watch against the
server's `max_connections`.

`networkPolicy.allowExternal` defaults to `false`. Database roles and RLS are the
real authorization boundary, but there is no reason for every pod in the cluster
to reach the API port as well.

## Configuration examples

External database, JWT-only access, behind an Ingress:

```yaml
postgresql:
  enabled: false
externalDatabase:
  existingSecret: postgrest-db      # key: database-uri
jwt:
  existingSecret: postgrest-jwt     # key: jwt-secret
db:
  schemas: api
  anonRole: ""                      # no anonymous access
ingress:
  enabled: true
  hosts:
    - host: api.example.com
  tls:
    - hosts: [api.example.com]
      secretName: api-tls
networkPolicy:
  allowExternal: true
```

A PostgREST setting the chart does not expose — just use its env var:

```yaml
extraEnvVars:
  - name: PGRST_DB_MAX_ROWS
    value: "1000"
  - name: PGRST_SERVER_CORS_ALLOWED_ORIGINS
    value: "https://app.example.com"
```

## Uninstall

```bash
helm uninstall api
```

The bundled PostgreSQL's PVC is retained by Kubernetes on uninstall — delete it
explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=api
```

## Notes

The chart depends on the `quench-common` library chart and, by default, the
QuenchWorks `postgresql` chart, both pulled from
`oci://ghcr.io/quenchworks/charts`. The container runs as nonroot on a read-only
root filesystem with all capabilities dropped, and the image is pinned by digest.
PostgREST is MIT licensed.

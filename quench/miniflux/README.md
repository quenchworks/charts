# Quenchworks miniflux

Hardened [Miniflux](https://miniflux.app/) feed reader on a minimal, nonroot,
0-CVE image pinned by digest. Miniflux is stateless (all state lives in
PostgreSQL), so it runs as a plain Deployment. This chart ships a **bundled
PostgreSQL by default** for a self-contained install, and also supports bringing
your own external database.

## Install

Self-contained (bundled PostgreSQL):

```bash
helm install my-miniflux oci://ghcr.io/quenchworks/charts/miniflux
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-miniflux-miniflux 8080:80
# http://127.0.0.1:8080
```

The default admin login is `admin` with a password stored in the release Secret:

```bash
kubectl get secret my-miniflux-miniflux -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

> **Change the password after first login** under Settings. For production, set a
> strong `postgresql.auth.password` (it is shared with miniflux's `DATABASE_URL`)
> and either set `admin.password` / `admin.existingSecret` or use an external DB.

## Database modes

**Bundled PostgreSQL (default).** `postgresql.enabled=true` pulls QuenchWorks' own
hardened `postgresql` subchart. Miniflux's `DATABASE_URL` is built from
`postgresql.auth.*` and points at the subchart's `<release>-postgresql` Service.
The password is shared between the subchart and miniflux, so both read the same
`postgresql.auth.password`.

**External PostgreSQL.** Disable the subchart and point at your own database:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres.db.svc.cluster.local
  port: 5432
  user: miniflux
  password: change-me
  database: miniflux
  sslmode: require
```

Or supply a ready connection string via a Secret:

```yaml
postgresql:
  enabled: false
externalDatabase:
  existingSecret: my-db-secret
  existingSecretURLKey: database-url # value: postgres://user:pass@host:5432/db?sslmode=require
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/miniflux \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/miniflux \
  --owner quenchworks
```

## Values

| Key                           | Default                               | Notes                                                                                     |
| ----------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- | ----------- |
| `image.repository`            | `ghcr.io/quenchworks/images/miniflux` |                                                                                           |
| `image.digest`                | (CI-written)                          | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                   | Stateless; can be scaled out.                                                             |
| `containerPort`               | `8080`                                | Port miniflux binds (nonroot). Wired to `LISTEN_ADDR`.                                    |
| `service.port`                | `80`                                  | Service port, forwards to the container's `http` port.                                    |
| `runMigrations`               | `true`                                | Runs schema migrations on startup (idempotent).                                           |
| `admin.create`                | `true`                                | Seeds an admin only when the DB has no users.                                             |
| `admin.username`              | `admin`                               |                                                                                           |
| `admin.password`              | `""`                                  | Random+persisted if empty. Or use `admin.existingSecret`.                                 |
| `postgresql.enabled`          | `true`                                | Bundled hardened PostgreSQL subchart.                                                     |
| `postgresql.auth.username`    | `postgres`                            | DB owner (superuser); must differ from the DB name for the bundled image to create it.    |
| `postgresql.auth.password`    | `miniflux`                            | **Shared with `DATABASE_URL`; override for production.**                                  |
| `postgresql.auth.database`    | `miniflux`                            |                                                                                           |
| `externalDatabase.*`          | (unset)                               | Used when `postgresql.enabled=false`.                                                     |
| `serviceAccount.create`       | `true`                                | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                               | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                                | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                                | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                               | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                  | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                  | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                                | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                  | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                  | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped; only an `emptyDir` `/tmp` is writable. Miniflux serves `GET /healthcheck`
(returns `200 OK`), used for both liveness and readiness probes. The database
connection string and admin password are kept in a Kubernetes Secret.

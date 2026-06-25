# Quenchworks ZITADEL

Hardened [ZITADEL](https://zitadel.com/) — cloud-native identity infrastructure
(OIDC / OAuth2 / SAML, multi-tenancy, self-service, management API and console) — on a
minimal, nonroot, 0-CVE image pinned by digest. The server is a single static Go
binary that runs as uid `1001` on a read-only root filesystem and serves HTTP/2
cleartext (h2c, gRPC + REST + console multiplexed) on port `8080`.

ZITADEL is **stateless**: all state lives in an external **PostgreSQL**. This chart
bundles the Quenchworks PostgreSQL chart by default and can also point at an external
database. The container runs the cold-start subcommand `start-from-init`, which creates
the schema, seeds the first instance/admin, then serves — idempotent across restarts.
All configuration is driven via `ZITADEL_*` environment variables.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install id oci://ghcr.io/quenchworks/charts/zitadel \
  --set masterkey="ChangeMeToA32CharacterMasterKey!" \
  --set externalDomain=id.example.com --set externalSecure=true
```

`masterkey` must be **exactly 32 characters**. Leave it empty to auto-generate one
(persisted in the managed Secret across upgrades).

## Connect

```bash
kubectl port-forward svc/id-zitadel 8080:8080
# console: http://localhost:8080/ui/console
```

Health / discovery:

```bash
curl -fsS http://localhost:8080/debug/healthz                      # process up
curl -fsS http://localhost:8080/debug/ready                        # serving
curl -fsS http://localhost:8080/.well-known/openid-configuration   # OIDC discovery
```

First admin credentials (seeded once on first boot):

```bash
kubectl get secret id-zitadel -o jsonpath='{.data.admin-password}' | base64 -d
# username: firstInstance.admin.username (default: zitadel-admin)
```

## External addressing

`externalDomain` / `externalPort` / `externalSecure` are baked into the issuer and OIDC
discovery URLs, so they **must** match how clients actually reach ZITADEL. TLS is
expected to terminate at an ingress/proxy (the app runs with `--tlsMode disabled`); set
`externalSecure=true` behind HTTPS ingress.

## Database

### Bundled (default)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart. The bundled
image creates `postgresql.auth.username` as the **superuser**, so it serves both
ZITADEL's runtime connection and its schema-creating admin connection. The username and
database must differ (the image only creates the app DB when `POSTGRES_DB` differs from
both `postgres` and `POSTGRES_USER`). Set `postgresql.auth.password` for a deterministic
install.

```yaml
postgresql:
  enabled: true
  auth:
    username: zitadeluser   # becomes the PostgreSQL superuser
    password: ""            # generated into the Secret if empty
    database: zitadel
```

### External

Point at an existing PostgreSQL and disable the subchart. ZITADEL needs a runtime role
and an admin role able to create its schema on first boot:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: postgres.example.com
  port: 5432
  database: zitadel
  user: zitadel
  password: "s3cret"
  adminUsername: postgres
  adminPassword: "admin-s3cret"
  sslMode: disable            # disable | require | verify-ca | verify-full
  # or reference a Secret supplying db-user-password and db-admin-password:
  existingSecret: ""
  existingSecretUserPasswordKey: db-user-password
  existingSecretAdminPasswordKey: db-admin-password
```

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/zitadel` | Image repository |
| `image.digest` | pinned `sha256:…` | Image digest (never a tag) |
| `replicaCount` | `1` | Stateless; scale horizontally as needed |
| `service.port` | `8080` | h2c listener / service port |
| `externalDomain` | `localhost` | Public domain (`ZITADEL_EXTERNALDOMAIN`) |
| `externalPort` | `8080` | Public port (`ZITADEL_EXTERNALPORT`) |
| `externalSecure` | `false` | HTTPS in front (`ZITADEL_EXTERNALSECURE`) |
| `masterkey` | `""` (generated) | `ZITADEL_MASTERKEY`, exactly 32 chars |
| `firstInstance.orgName` | `QuenchWorks` | Seeded org name (first boot) |
| `firstInstance.admin.username` | `zitadel-admin` | Seeded admin username |
| `firstInstance.admin.password` | `""` (generated) | Seeded admin password |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart |
| `postgresql.auth.{username,password,database}` | `zitadeluser` / `""` / `zitadel` | Bundled DB credentials (username = superuser) |
| `externalDatabase.*` | `""` | External DB connection (when `postgresql.enabled=false`) |
| `networkPolicy.enabled` | `true` | Restrict traffic; egress opened to the DB port |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` |

The image is pinned by digest and cosign-signed:

```bash
cosign verify ghcr.io/quenchworks/images/zitadel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

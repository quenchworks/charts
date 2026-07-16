# Quenchworks ZITADEL

Hardened [ZITADEL](https://zitadel.com/) — cloud-native identity infrastructure
(OIDC / OAuth2 / SAML, multi-tenancy, self-service, and a built-in management API
and console) — on a minimal, nonroot, 0-CVE image pinned by digest and
cosign-signed (keyless / Sigstore). The server is a single static Go binary that
runs as uid `1001` on a read-only root filesystem with all capabilities dropped,
serving HTTP/2 cleartext (h2c: gRPC, REST, and console multiplexed) on port
`8080`.

ZITADEL is stateless: all state lives in an external PostgreSQL. This chart
bundles the Quenchworks PostgreSQL chart by default and can also point at an
external database. The container runs the cold-start subcommand
`start-from-init`, which creates the schema, seeds the first instance and admin,
then serves — idempotent across restarts. All configuration is driven through
`ZITADEL_*` environment variables.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install id oci://ghcr.io/quenchworks/charts/zitadel \
  --set masterkey="ChangeMeToA32CharacterMasterKey!" \
  --set externalDomain=id.example.com --set externalSecure=true
```

`masterkey` must be exactly 32 characters. Leave it empty to auto-generate one
(persisted in the managed Secret across upgrades).

Reach the console over a port-forward:

```bash
kubectl port-forward svc/id-zitadel 8080:8080
# console: http://localhost:8080/ui/console
```

Health and discovery endpoints:

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

## Verify the image

The chart deploys two images: ZITADEL and the bundled PostgreSQL. Both are
cosign-signed keyless and pinned by digest.

```bash
cosign verify ghcr.io/quenchworks/images/zitadel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify ghcr.io/quenchworks/images/postgresql \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/zitadel --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/postgresql --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/zitadel` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment; scale horizontally as needed. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | h2c listener and Service port. |
| `externalDomain` | `localhost` | Public domain (`ZITADEL_EXTERNALDOMAIN`). |
| `externalPort` | `8080` | Public port (`ZITADEL_EXTERNALPORT`). |
| `externalSecure` | `false` | HTTPS in front (`ZITADEL_EXTERNALSECURE`). |
| `masterkey` | `""` (generated) | `ZITADEL_MASTERKEY`, exactly 32 chars. |
| `firstInstance.orgName` | `QuenchWorks` | Seeded org name (first boot only). |
| `firstInstance.admin.username` | `zitadel-admin` | Seeded admin username. |
| `firstInstance.admin.password` | `""` (generated) | Seeded admin password. |
| `resources.requests` | `250m / 512Mi` | CPU / memory requests. |
| `resources.limits` | `2 / 1Gi` | CPU / memory limits. |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart. |
| `postgresql.auth.username` | `zitadeluser` | Bundled DB user (becomes the superuser). |
| `postgresql.auth.password` | `""` | Generated into the Secret if empty. |
| `postgresql.auth.database` | `zitadel` | Bundled DB name (must differ from the username). |
| `postgresql.primary.persistence.size` | `8Gi` | Bundled DB PVC size. |
| `externalDatabase.*` | `""` | External DB connection (when `postgresql.enabled=false`). |
| `externalDatabase.sslMode` | `disable` | `disable`, `require`, `verify-ca`, or `verify-full`. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress on h2c; egress opened to DNS and the DB port. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `command` | `["/usr/bin/zitadel"]` | Image entrypoint; Kubernetes replaces it, so it names the binary. |
| `args` | `["start-from-init", "--masterkeyFromEnv", "--tlsMode", "disabled"]` | Cold-start subcommand and flags. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

ZITADEL runs as a stateless **Deployment** behind a ClusterIP Service; all state
lives in PostgreSQL, which runs as a StatefulSet via the bundled subchart. The
container serves h2c on container port `8080` (gRPC, REST, and the console
multiplexed over HTTP/2 cleartext), and the Service maps the same port. TLS is
expected to terminate at an ingress or proxy — the app runs with
`--tlsMode disabled`.

On boot the container runs `start-from-init`, which connects to PostgreSQL with
an admin (schema-creating) role, creates the schema, seeds the first instance and
admin user, then serves. It is idempotent, so it is safe across restarts. The
generated `masterkey`, admin password, and DB credentials live in a single
managed Secret; a `checksum/secret` annotation rolls the pod when they change.

Probes reflect the boot sequence: liveness hits `/debug/healthz` (process up),
readiness hits `/debug/ready` (returns 200 only once ZITADEL has connected to
PostgreSQL, run init/migrations, and is actually serving). The first-boot
readiness window is generous because `start-from-init` runs against an empty
database. The kubelet performs the GET; the image ships no shell HTTP client.

`externalDomain` / `externalPort` / `externalSecure` are baked into the issuer
and OIDC discovery URLs, so they must match how clients actually reach ZITADEL.
Set `externalSecure=true` behind an HTTPS ingress.

The NetworkPolicy allows ingress on the h2c port (external by default, since
ZITADEL has its own auth) and opens egress to DNS, the database port, and general
outbound (federated IdPs, webhooks, SMTP, OIDC fetches).

## Configuration examples

Bundled PostgreSQL (default). The bundled image creates `postgresql.auth.username`
as the superuser, so it serves both ZITADEL's runtime connection and its
schema-creating admin connection. The username and database must differ, since
the image only creates the app DB when `POSTGRES_DB` differs from both `postgres`
and `POSTGRES_USER`. Set a password for a deterministic install:

```yaml
postgresql:
  enabled: true
  auth:
    username: zitadeluser   # becomes the PostgreSQL superuser
    password: ""            # generated into the Secret if empty
    database: zitadel
```

External PostgreSQL. Point at an existing database and disable the subchart.
ZITADEL needs a runtime role and an admin role able to create its schema on first
boot:

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

## Uninstall

```bash
helm uninstall id
```

The PostgreSQL PVC provisioned by the bundled subchart is retained by Kubernetes
on uninstall — delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=id
```

## Notes

The chart depends on the `quench-common` library chart and the Quenchworks
`postgresql` chart, both pulled from `oci://ghcr.io/quenchworks/charts`. The
container runs as nonroot on a read-only root filesystem with all capabilities
dropped, and both images are pinned by digest. ZITADEL needs no writable
filesystem directories. Keep the NetworkPolicy as the trust boundary and
terminate TLS at an ingress before exposing the console beyond the cluster.

# Quenchworks Keycloak

Hardened [Keycloak](https://www.keycloak.org/) — identity & access management
(SSO, OIDC, SAML) — on a minimal, nonroot, 0-CVE image pinned by digest. The image
bakes the **optimized** Quarkus build (`kc.sh build` is run at image-build time with
the Postgres driver and health/metrics endpoints) so the runtime starts fast on a
read-only root filesystem. The admin console + protocol endpoints are on port `8080`;
health and metrics are on the management port `9000`.

Keycloak is stateless given its database — all realm/user/session state lives in
**PostgreSQL**. This chart bundles the Quenchworks PostgreSQL chart by default and
can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install sso oci://ghcr.io/quenchworks/charts/keycloak
```

The bootstrap admin password is stored in a Secret (generated if you do not supply
one).

## Connect

```bash
# admin password
kubectl get secret sso-keycloak -o jsonpath="{.data.admin-password}" | base64 -d

# reach the admin console
kubectl port-forward svc/sso-keycloak 8080:8080
# open http://127.0.0.1:8080/admin/  (user: admin)
```

Health check (management port `9000`):

```bash
kubectl port-forward svc/sso-keycloak 9000:9000
curl -fsS http://127.0.0.1:9000/health/ready
# -> {"status":"UP", ...}
```

## Database

### Bundled (default)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart. Both Keycloak
and PostgreSQL share the deterministic credentials under `postgresql.auth`, so
`KC_DB_URL` is derived from the subchart's service automatically:

```yaml
postgresql:
  enabled: true
  auth:
    username: kcadmin        # MUST differ from `database` (image init quirk)
    password: keycloak       # set a real password in production
    database: keycloak
```

### External

Set `postgresql.enabled=false` and fill in `externalDatabase`:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.com
  port: 5432
  database: keycloak
  user: keycloak
  password: ""               # or supply existingSecret
  existingSecret: ""
  existingSecretPasswordKey: password
```

### Override the DB password Secret (`db.existingSecret`)

`db.existingSecret` overrides the Secret `KC_DB_PASSWORD` is read from in **both**
modes. Empty (default) keeps the existing behavior — bundled reads the managed
`<release>-keycloak`/`db-password`, external reads `externalDatabase.existingSecret`.
Set it to point Keycloak at a Secret you control, e.g. so an umbrella chart can have
Keycloak and the bundled PostgreSQL share one fixed-name Secret:

```yaml
db:
  existingSecret: my-db-secret
  existingSecretPasswordKey: db-password
```

## Production

Behind an ingress/proxy that terminates TLS, set the public hostname and forwarded
headers so Keycloak builds correct issuer/redirect URLs:

```yaml
production:
  hostname: https://sso.example.com   # KC_HOSTNAME
  proxyHeaders: xforwarded            # KC_PROXY_HEADERS (or "forwarded")
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/keycloak \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

The bundled PostgreSQL image (`ghcr.io/quenchworks/images/postgresql`) verifies
the same way. Each build also ships an SPDX SBOM and SLSA provenance attestation;
verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/keycloak --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/postgresql --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/keycloak` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless given the DB; raise to scale (Infinispan clusters). |
| `auth.adminUser` | `admin` | Bootstrap admin (`KC_BOOTSTRAP_ADMIN_USERNAME`). |
| `auth.adminPassword` | (generated) | 24-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the admin user + password. |
| `production.hostname` | `""` | Public URL → `KC_HOSTNAME`. |
| `production.proxyHeaders` | `""` | `xforwarded` / `forwarded` → `KC_PROXY_HEADERS`. |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart. |
| `postgresql.auth.{username,password,database}` | `keycloak` | Deterministic shared DB creds. |
| `externalDatabase.*` | `""` | Used when `postgresql.enabled=false`. |
| `db.existingSecret` | `""` | Override the Secret `KC_DB_PASSWORD` is read from (both modes). Empty = unchanged. |
| `db.existingSecretPasswordKey` | `db-password` | Key within `db.existingSecret`. |
| `service.port` | `8080` | HTTP (UI + protocol endpoints). |
| `service.managementPort` | `9000` | Health + metrics. |
| `networkPolicy.enabled` | `true` | Ingress 8080 (+9000 in-namespace), egress to DB. |
| `networkPolicy.allowExternal` | `true` | Console is usually reached externally; set false to restrict. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The writable paths Keycloak needs — `/conf` (seeded from the shipped dist),
`/data` (runtime state), and `/tmp` (JVM tmpdir) — are emptyDir; no PVC is mounted on
the Keycloak pod (state lives in PostgreSQL). Admin and database credentials live in
Kubernetes Secrets. Probes hit `/health/ready` and `/health/live` on the management
port.

## Uninstall

```bash
helm uninstall sso
```

The Keycloak pod holds no PVC (state lives in PostgreSQL). When the bundled
PostgreSQL is used, its PVC is retained by Kubernetes on uninstall; delete it
explicitly if you want the identity data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=sso
```

## Notes

Depends on the `quench-common` library chart and the Quenchworks `postgresql` chart,
both pulled from `oci://ghcr.io/quenchworks/charts`. The optimized build means the
runtime never augments at boot, keeping the rootfs read-only.

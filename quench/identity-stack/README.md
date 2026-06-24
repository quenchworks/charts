# identity-stack

A hardened, **operator-free** self-hosted single sign-on bundle: **Keycloak**
(OIDC/SAML identity provider), **PostgreSQL** (Keycloak's database) and
**oauth2-proxy** (the authenticating reverse proxy you place in front of your
apps), wired together so you get working SSO in front of your workloads out of
the box.

It gives you the everyday value of a managed identity platform — a real OIDC
provider, a user/role store, and a drop-in auth gateway for apps that have no
login of their own — **without any operator or CRDs**. The cross-wiring
(Keycloak's JDBC connection to PostgreSQL, and oauth2-proxy's OIDC issuer
pointing at Keycloak) is handled by the umbrella; you mostly create a realm and a
client and point the proxy at your app. Every component image is
QuenchWorks-hardened: built from source on Wolfi, nonroot, 0 fixable CVEs,
cosign-signed with an SBOM and SLSA provenance, and pinned by digest.

| Component | Role | Component chart |
|-----------|------|-----------------|
| **Keycloak** | OIDC/SAML identity provider — realms, users, clients, tokens | `quench/keycloak` |
| **PostgreSQL** | Keycloak's backing store (all identity state lives here) | `quench/postgresql` (bundled inside `quench/keycloak`) |
| **oauth2-proxy** | authenticating reverse proxy in front of an upstream app | `quench/oauth2-proxy` |

> PostgreSQL is not a direct dependency of this umbrella — the `quench/keycloak`
> chart already bundles `quench/postgresql` and wires Keycloak to it. This stack
> adds Keycloak + oauth2-proxy and the glue that points the proxy at Keycloak.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+ (OCI support)

## Usage

The chart is distributed as an OCI artifact:

```sh
oci://ghcr.io/quenchworks/charts/identity-stack
```

### Install

```sh
helm install id oci://ghcr.io/quenchworks/charts/identity-stack
```

Open the Keycloak admin console and read the generated admin password:

```sh
kubectl get secret id-keycloak -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/id-keycloak 8080:8080
# http://127.0.0.1:8080/admin/   (user: admin)
```

Keycloak boots the Quarkus runtime, connects to PostgreSQL and runs Liquibase
migrations on first start, so allow a few minutes before it reports ready.

### Uninstall

```sh
helm uninstall id
```

This removes everything the chart created. **No CRDs are installed, so there is
nothing to clean up afterwards.** The PostgreSQL PersistentVolumeClaim is retained
by Helm convention; delete it by hand if you want the identity data gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=id
```

### Upgrade

```sh
helm upgrade id oci://ghcr.io/quenchworks/charts/identity-stack
```

There are no CRDs, so upgrades never require a separate CRD apply step. A major
chart version bump signals a breaking values change; check the release notes.

## The SSO flow

```
            (1) GET /                          (3) authenticate
 browser ───────────────▶ oauth2-proxy ─────────────────────────▶ Keycloak
    ▲                         │  ▲                                     │
    │ (5) proxied response    │  │ (4) ID/access token                 │ reads users,
    │                         ▼  └─────────────────────────────────────┘ realms, clients
    └───────────────────── your upstream app                          PostgreSQL
                          (2) only after auth
```

1. A browser hits **oauth2-proxy** (exposed via your Ingress).
2. Unauthenticated requests are redirected to **Keycloak** to log in.
3. Keycloak authenticates the user against its data in **PostgreSQL**.
4. oauth2-proxy validates the returned OIDC token.
5. Authenticated requests are proxied to **your upstream app**.

## How it's wired

The umbrella owns a thin glue layer; everything else passes straight through to
the component charts. quench-common names every object `<release>-<chart>`, so the
in-cluster services are `<release>-postgresql:5432`, `<release>-keycloak:8080`
(plus `:9000` for health/metrics) and `<release>-oauth2-proxy:4180`.

- **Keycloak → PostgreSQL (automatic)** — PostgreSQL is the `quench/postgresql`
  chart **bundled inside `quench/keycloak`** (`keycloak.postgresql.enabled=true`).
  The keycloak chart wires Keycloak to it on its own: its `keycloak.db.host` helper
  resolves to `<release>-postgresql` and it builds
  `KC_DB_URL = jdbc:postgresql://<release>-postgresql:5432/keycloak` itself, sharing
  the deterministic credentials in `keycloak.postgresql.auth` (user `kcadmin`,
  database `keycloak`, password). This umbrella sets **no** `externalDatabase` and
  **no** `KC_DB_URL` override — Keycloak emits a single `KC_DB_URL` env.
- **The umbrella Secret** — `values.yaml` is **not** templated, so the one value
  that must contain the release name cannot live there. The umbrella renders a
  fixed-name Secret, **`identity-stack-config`** (`templates/config.yaml`), holding:
  - `OIDC_ISSUER_URL` = `http://<release>-keycloak:8080/realms/<realm>`

  **Fixed name ⇒ run one identity-stack per namespace.**
- **oauth2-proxy → Keycloak** — `provider: oidc`. The OIDC issuer URL needs the
  release name, so it is injected as `OAUTH2_PROXY_OIDC_ISSUER_URL` from the
  umbrella Secret via `oauth2Proxy.extraEnvVars` (oauth2-proxy reads `OAUTH2_PROXY_*`
  env as config, equivalent to `--oidc-issuer-url`). The client id/secret, the
  32-byte cookie secret, `email-domain=*` and `upstream=static://200` are set
  through the oauth2-proxy chart's `config` passthrough.

### Why no operator?

There is no identity operator to run, no CRDs, and no admission webhook. Keycloak
is configured through env/values and its own admin API; oauth2-proxy through flags
and `OAUTH2_PROXY_*` env. You lose nothing an operator would have given you here —
realms, clients and users are managed in Keycloak itself — and you gain a smaller,
hardened footprint with nothing cluster-scoped to upgrade.

## Put oauth2-proxy in front of YOUR app

This is the point of the stack. Two one-time steps:

**1. Register an OIDC client in Keycloak.** In the admin console, create (or
reuse) a realm, then create a *confidential* OpenID Connect client:

- Client ID: `oauth2-proxy` (or your own — set `shared.oidcClientID`)
- Client authentication: **On**
- Valid redirect URIs: `https://<your-app-host>/oauth2/callback`

Copy the generated client secret. This release points the proxy at the realm in
`shared.oidcRealm` (default `master`); set it to your realm and upgrade.

**2. Point the proxy at your app and set the real client.** The client secret and
cookie secret flow to oauth2-proxy from the umbrella Secret, so set them once under
`shared.*` (no secret ever becomes a plaintext command-line flag):

```sh
helm upgrade id oci://ghcr.io/quenchworks/charts/identity-stack \
  --set shared.oidcRealm=myrealm \
  --set shared.oidcClientID=oauth2-proxy \
  --set shared.oidcClientSecret=<client-secret> \
  --set oauth2Proxy.config.clientID=oauth2-proxy \
  --set oauth2Proxy.config.upstream=http://myapp.default.svc:8080
```

Then expose `id-oauth2-proxy:4180` through your Ingress. The default
`upstream: static://200` is a placeholder that returns HTTP 200 so the proxy is
healthy before a real backend is wired — replace it with your app's Service URL.
oauth2-proxy can also run as a forward-auth / `auth_request` endpoint for an
existing Ingress controller instead of inline proxying.

## Database

### Bundled database (default)

PostgreSQL ships inside the keycloak chart and is deployed automatically. Keycloak
auto-wires `KC_DB_URL` to `jdbc:postgresql://<release>-postgresql:5432/keycloak`.
Both Keycloak (`KC_DB_PASSWORD`) and the bundled PostgreSQL read the DB password
from **the same** umbrella Secret + key — `identity-stack-config`/`db-password` —
so they always match. The password is generated when `shared.dbPassword` is empty
and preserved across upgrades; nothing sensitive lives in values.

```sh
helm install id oci://ghcr.io/quenchworks/charts/identity-stack
# optional: pin the DB password instead of generating it
helm install id oci://ghcr.io/quenchworks/charts/identity-stack \
  --set shared.dbPassword=my-strong-password
```

### Use your own PostgreSQL

Set `keycloak.postgresql.enabled=false` (no bundled PostgreSQL StatefulSet is
rendered), point Keycloak at your server with `keycloak.externalDatabase.*`, and
supply the password from a Secret you pre-create via `keycloak.db.existingSecret`:

```sh
kubectl create secret generic my-db-secret \
  --from-literal=password='<your-db-password>'

helm install id oci://ghcr.io/quenchworks/charts/identity-stack \
  --set keycloak.postgresql.enabled=false \
  --set keycloak.externalDatabase.host=pg.example.com \
  --set keycloak.externalDatabase.port=5432 \
  --set keycloak.externalDatabase.database=keycloak \
  --set keycloak.externalDatabase.user=kcadmin \
  --set keycloak.db.existingSecret=my-db-secret \
  --set keycloak.db.existingSecretPasswordKey=password
```

`KC_DB_PASSWORD` then reads `my-db-secret`/`password`; `KC_DB_URL` points at
`pg.example.com`. No password appears in values or as a plaintext env value.

## Multiple releases

The umbrella Secret `identity-stack-config` has a **fixed name**, so install one
identity-stack per namespace. For several stacks, give each its own namespace.

## High availability

- **Keycloak** is stateless given the database; raise `keycloak.replicaCount` (the
  Infinispan cache forms a cluster).
- **oauth2-proxy** scales horizontally; raise `oauth2Proxy.replicaCount` or enable
  `oauth2Proxy.autoscaling`.
- **PostgreSQL** (bundled inside keycloak) is a single primary here; for HA use an
  external managed Postgres: set `keycloak.postgresql.enabled=false` and point
  Keycloak at it via `keycloak.externalDatabase` (host, port, database, user,
  password) — the keycloak chart builds `KC_DB_URL` from those values.

## Configuration

Each top-level block passes straight through to its component chart; see each
chart's own README for the full surface. The `shared.*` block is the single source
of truth for the credentials the umbrella threads across components.

### Key values

| Value | Default | Description |
|-------|---------|-------------|
| `shared.dbPassword` | `""` (generated) | DB password shared by Keycloak + the bundled PostgreSQL. Leave empty to generate; set to pin. |
| `shared.oidcClientSecret` | `""` (generated) | oauth2-proxy OIDC client secret. Set to your registered Keycloak client's secret. |
| `shared.cookieSecret` | `""` (generated 32-byte) | oauth2-proxy cookie signing secret (16/24/32 bytes). |
| `shared.oidcRealm` | `master` | Keycloak realm oauth2-proxy points its OIDC issuer at. |
| `shared.oidcClientID` | `oauth2-proxy` | OIDC client id (register it in Keycloak). |
| `keycloak.enabled` | `true` | Deploy Keycloak. |
| `keycloak.postgresql.enabled` | `true` | Deploy Keycloak's bundled PostgreSQL (auto-wired). Set false for your own DB via `keycloak.externalDatabase`. |
| `keycloak.postgresql.auth.username` | `kcadmin` | DB login role (must differ from the database name). |
| `keycloak.postgresql.auth.database` | `keycloak` | Keycloak's database. |
| `keycloak.db.existingSecret` | `identity-stack-config` | Secret `KC_DB_PASSWORD` is read from (point at your own Secret for an external DB). |
| `keycloak.db.existingSecretPasswordKey` | `db-password` | Key within `keycloak.db.existingSecret`. |
| `keycloak.externalDatabase.host` | `""` | External PostgreSQL host (used when `keycloak.postgresql.enabled=false`). |
| `keycloak.auth.adminUser` | `admin` | Master-realm bootstrap admin user. |
| `keycloak.auth.adminPassword` | generated | Admin password (24-char generated if empty). |
| `keycloak.production.hostname` | `""` | Public URL for correct redirect/issuer URLs in production. |
| `keycloak.production.proxyHeaders` | `""` | `xforwarded`/`forwarded` when behind a TLS-terminating proxy. |
| `oauth2Proxy.enabled` | `true` | Deploy oauth2-proxy. |
| `oauth2Proxy.config.upstream` | `static://200` | Upstream app the proxy fronts. **Point at your app.** |
| `oauth2Proxy.config.emailDomain` | `*` | Restrict authenticated users to these email domains. |

## Security posture

- **Hardened images** — every component (Keycloak, PostgreSQL, oauth2-proxy) is a
  QuenchWorks image: built from source on Wolfi, nonroot, read-only rootfs, 0
  fixable CVEs, cosign-signed with an SBOM + SLSA provenance, pinned by digest.
- **No plaintext secrets** — the DB password, OIDC client secret and cookie secret
  live only in the umbrella Secret `identity-stack-config` (generated when the
  `shared.*` value is empty, preserved across upgrades). Keycloak and the bundled
  PostgreSQL read the DB password from the same Secret + key, and oauth2-proxy
  reads its secrets via `OAUTH2_PROXY_*` env — none appear as a plaintext flag or
  env `value:`.
- **No host access** — unlike the observability stack, nothing here needs the host:
  no `hostPID`, no host mounts, no privileged containers.
- **No operator, no CRDs, no webhooks** — nothing cluster-scoped to keep patched.
- **NetworkPolicies** ship with each component; Keycloak and oauth2-proxy allow
  external ingress by default (they are reached by browsers/relying apps),
  PostgreSQL does not.
- **Before production** — register a real Keycloak realm + confidential client and
  set `shared.oidcClientID` / `shared.oidcClientSecret`; optionally pin
  `shared.dbPassword`. Set `keycloak.production.hostname` to your public URL.

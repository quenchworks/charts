# Quenchworks Kratos

Hardened [Ory Kratos](https://www.ory.sh/kratos/) — an API-first identity
server (registration, login, MFA, account recovery, profile management) — on
a minimal, nonroot, 0-CVE image, cosign-signed (keyless / Sigstore) and pinned
by digest.

Kratos ships **no login/registration UI** — it is an identity API you build
your own UI against. All state lives in PostgreSQL, so the server itself runs
as a stateless Deployment. This chart bundles the Quenchworks PostgreSQL
chart by default and can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with a generated password
helm install identity oci://ghcr.io/quenchworks/charts/kratos
```

## Connect

```bash
kubectl port-forward svc/identity-kratos 4433:4433
curl http://127.0.0.1:4433/health/alive
```

## Identity schema and flows

The default identity schema is a single required `email` trait (used as the
password-method identifier), and `registration`/`login`/`settings` flows are
enabled while `recovery`/`verification` are **disabled** (both require a
configured SMTP courier, which this chart does not wire up). Override either
via `config.yaml` (full `kratos.yaml` replacement) or `config.identitySchema`
(your own identity schema JSON).

## Admin API

The Admin API (identity management + the health checks) has no
authentication of its own, so it is **not** exposed on the Service by default
(`service.exposeAdmin: false`). Reach it from within the namespace via a pod
port-forward, or set `service.exposeAdmin: true` behind a NetworkPolicy you
trust.

## Database

A `migrate` initContainer runs `kratos migrate sql -e --yes` on every pod
start (a no-op once the schema is current) before the server boots. Point at
an external database with:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres.example.com
  database: kratos
  user: kratos
  password: "..."          # or existingSecret / existingSecretDsnKey
```

## Values

See [`values.yaml`](./values.yaml) for the full set of options, and
[`ci/default-values.yaml`](./ci/default-values.yaml) for a minimal,
CI-verified install.

The image is pinned by digest and signed. Verify it:

```bash
cosign verify ghcr.io/quenchworks/images/kratos \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

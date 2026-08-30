# Quenchworks Hydra

Hardened [Ory Hydra](https://www.ory.sh/hydra/) — a certified OAuth2 / OpenID
Connect server — on a minimal, nonroot, 0-CVE image, cosign-signed (keyless /
Sigstore) and pinned by digest.

Hydra is a **token and consent service**, not a login UI: it delegates
authentication and the consent screen to your own application over its Admin
API. All state lives in PostgreSQL, so the server itself runs as a stateless
Deployment. This chart bundles the Quenchworks PostgreSQL chart by default and
can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with a generated password
helm install auth oci://ghcr.io/quenchworks/charts/hydra
```

## Connect

```bash
kubectl port-forward svc/auth-hydra 4444:4444
curl http://127.0.0.1:4444/.well-known/openid-configuration
```

Set `urls.login` / `urls.consent` / `urls.logout` to your own login+consent
application before issuing real tokens — the chart's defaults are placeholders
that only let the server boot for evaluation.

## Admin API

The Admin API (client + token-lifecycle management, plus the health checks)
has no authentication of its own, so it is **not** exposed on the Service by
default (`service.exposeAdmin: false`). Reach it from within the namespace via
a pod port-forward, or set `service.exposeAdmin: true` behind a NetworkPolicy
you trust.

## Database

A `migrate` initContainer runs `hydra migrate sql -e --yes` on every pod start
(a no-op once the schema is current) before the server boots. Point at an
external database with:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres.example.com
  database: hydra
  user: hydra
  password: "..."          # or existingSecret / existingSecretDsnKey
```

## Values

See [`values.yaml`](./values.yaml) for the full set of options, and
[`ci/default-values.yaml`](./ci/default-values.yaml) for a minimal,
CI-verified install.

The image is pinned by digest and signed. Verify it:

```bash
cosign verify ghcr.io/quenchworks/images/hydra \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

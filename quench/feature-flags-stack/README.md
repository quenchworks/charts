# Quenchworks feature-flags-stack

Feature flags and gradual rollouts in one install: [Unleash](https://github.com/Unleash/unleash)
8.2.1 with PostgreSQL, on QuenchWorks images (nonroot, CVE-gated at build, pinned by digest,
cosign-signed). The stack generates the API tokens your services and front ends use at install
and keeps them across upgrades, so an SDK can be configured before anyone opens the UI.

## Install

```bash
helm install flags oci://ghcr.io/quenchworks/charts/feature-flags-stack -n flags --create-namespace
```

Then read a token and point an SDK at `http://flags-unleash.flags:4242/api`:

```bash
kubectl -n flags get secret feature-flags-api-tokens -o jsonpath='{.data.backend-production}' | base64 -d
```

## API tokens

The Secret `feature-flags-api-tokens` holds five tokens in Unleash's `project:environment.secret`
form, all for the `default` project:

| Key | Type | For |
|---|---|---|
| `backend-development`, `backend-production` | backend | server SDKs, `/api/client` |
| `frontend-development`, `frontend-production` | frontend | web and mobile SDKs, `/api/frontend` |
| `admin` | admin | automation and CI, `/api/admin` |

Unleash creates them on start (`INIT_BACKEND_API_TOKENS`, `INIT_FRONTEND_API_TOKENS`,
`INIT_ADMIN_API_TOKENS`). Helm keeps the Secret on uninstall.

## Values

Everything under `unleash:` passes to the [unleash chart](../unleash), including its bundled
PostgreSQL (`unleash.postgresql`), the public URL (`unleash.url`) and the first administrator
(`unleash.admin`).

## Notes

- One stack per namespace: the token Secret has a fixed name, because the unleash subchart reads
  it from plain values.
- Unleash stores a token the first time it sees it. Replacing a value in the Secret adds a new
  token and leaves the old one valid; revoke it in the UI (Admin, API access).
- The admin token has full access to the Admin API. Keep it to automation that needs it.

# Ory Hydra

[Ory Hydra](https://www.ory.sh/hydra) is an OAuth 2.0 and OpenID Connect provider. It
issues tokens and runs the authorization flows; users log in through your own login and
consent app, which Hydra redirects to. This chart runs Hydra on the QuenchWorks
ory-hydra image with its state in PostgreSQL. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install hydra oci://ghcr.io/quenchworks/charts/ory-hydra \
  --set hydra.issuer=https://auth.example.com \
  --set hydra.loginUrl=https://login.example.com/login \
  --set hydra.consentUrl=https://login.example.com/consent
```

| Service | Port | Reach |
|---|---|---|
| `<release>-ory-hydra-public` | 4444 | clients and browsers: `/oauth2/*`, `/.well-known/*`, `/userinfo` |
| `<release>-ory-hydra-admin` | 4445 | always ClusterIP: client management, introspection, login and consent acceptance |

## Storage

| Mode | Values |
|---|---|
| bundled (default) | `postgresql.enabled=true`; the QuenchWorks postgresql chart, password generated into `<release>-postgresql` |
| external, full DSN | `postgresql.enabled=false`, `externalDatabase.existingDsnSecret` + `existingDsnSecretKey` |
| external, parts | `postgresql.enabled=false`, `externalDatabase.host/port/database/username/sslmode`, `existingSecret` + `existingSecretPasswordKey` (the password must be URL-safe) |

`hydra.autoMigrate=true` runs `hydra migrate sql up` in an init container on each
rollout. Until PostgreSQL accepts connections it exits non-zero and the kubelet retries it.

## Secrets

The chart generates `secretsSystem` and `secretsCookie` into `<release>-ory-hydra` on
install and keeps them on upgrade and uninstall (`helm.sh/resource-policy: keep`):
Hydra encrypts stored data with the system secret, so losing it makes that data
unreadable. Bring your own with `hydra.existingSecret`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `hydra.issuer` | `http://127.0.0.1:4444` | issuer URL as clients see it |
| `hydra.loginUrl`, `hydra.consentUrl` | `http://127.0.0.1:3000/...` | your login and consent app |
| `hydra.dev` | `false` | `--dev`: disables the TLS and HTTPS-issuer checks, local testing only |
| `hydra.config` | `{}` | extra Hydra settings as env vars, e.g. `TTL_ACCESS_TOKEN: 1h` |
| `replicas` | `1` | Hydra is stateless; scale out freely |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind with the bundled PostgreSQL, registers a
client through the admin API, mints a client_credentials token on the public API and
requires introspection to report it active.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

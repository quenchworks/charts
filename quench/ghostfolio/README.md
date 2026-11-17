# Quenchworks Ghostfolio

Hardened [Ghostfolio](https://github.com/ghostfolio/ghostfolio): a wealth management and portfolio tracker for
stocks, ETFs and crypto, with performance analysis. The image builds the NestJS API and the Angular client from
source and ships only the API's runtime dependencies; it runs as uid 1001 on a read-only root filesystem and is
CVE-gated at build, cosign-signed and pinned by digest. One finding without a fix (node-forge, unreachable) is
documented in a VEX statement.

The chart runs on the bundled QuenchWorks PostgreSQL and Valkey and generates `ACCESS_TOKEN_SALT` and
`JWT_SECRET_KEY`. Database migrations and the seed run at start.

## Install

```bash
helm install money oci://ghcr.io/quenchworks/charts/ghostfolio \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=money.example.com' \
  --set 'ingress.tls[0].hosts[0]=money.example.com' --set 'ingress.tls[0].secretName=money-tls'
```

Open it, choose "Get Started": the first account becomes the administrator. Keep its security token, then close
sign-up in Admin Control > Settings.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `secret.existingSecret` | `""` | A Secret with `access-token-salt` and `jwt-secret-key` instead of generated ones |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.existingSecret` with a `DATABASE_URL` |
| `valkey.enabled` | `true` | The bundled Valkey; or `externalRedis.*` |
| `settings` | `{}` | More environment variables (data provider keys, `LOG_LEVELS`) |
| `ingress.*` | off | Ghostfolio has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ghostfolio \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

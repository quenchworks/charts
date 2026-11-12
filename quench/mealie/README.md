# Quenchworks Mealie

Hardened [Mealie](https://github.com/mealie-recipes/mealie), a recipe manager and meal planner,
CVE-gated, cosign-signed and pinned by digest. The image is built from source (the Nuxt frontend
embedded in the Python app, psycopg2 built against Wolfi libpq) on a nonroot Wolfi base.

## Install

```bash
helm install mealie oci://ghcr.io/quenchworks/charts/mealie --set settings.BASE_URL=https://recipes.example.com
kubectl port-forward svc/mealie 9000
```

The first start creates the admin `changeme@example.com` with the password `MyPassword`. Log in
and change both at once, before the Service is reachable by anyone else. Mealie has no setting for
the initial password. Sign-ups are off (`ALLOW_SIGNUP: "false"`); invite users from the app.

## Storage and database

`/app/data` holds the SQLite database, recipe images and backups, on a PersistentVolumeClaim. One
replica with `Recreate`. For PostgreSQL:

```yaml
settings:
  DB_ENGINE: postgres
  POSTGRES_SERVER: postgres.db
  POSTGRES_DB: mealie
  POSTGRES_USER: mealie
extraEnvVarsSecret: mealie-db   # POSTGRES_PASSWORD
```

## TLS

Mealie serves plain HTTP. With `tls.enabled` a caddy sidecar terminates HTTPS on 8443 (Service port
`service.httpsPort`) and proxies to it over localhost. The certificate comes from
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in the
Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mealie \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `settings` | `BASE_URL`, sign-ups off, `TZ` | Mealie environment variables |
| `extraEnvVarsSecret` | `""` | Secret with `POSTGRES_PASSWORD`, SMTP or OIDC secrets |
| `persistence.size` | `5Gi` | The data volume |
| `service.port` | `9000` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

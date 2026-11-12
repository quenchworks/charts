# Quenchworks Kanboard

Hardened [Kanboard](https://github.com/kanboard/kanboard), Kanban project management, CVE-gated,
cosign-signed and pinned by digest. The image is the release served by php-fpm 8.4 behind a
from-source nginx under supervisord, on a nonroot Wolfi base.

## Install

```bash
helm install kanboard oci://ghcr.io/quenchworks/charts/kanboard
kubectl port-forward svc/kanboard 8080
```

The first start creates the user `admin` with the password `admin`. Log in and change it at once,
before the Service is reachable by anyone else. Kanboard has no setting for the initial password.

## Storage and database

`/var/www/app/data` holds the SQLite database, uploaded files and cache, on a
PersistentVolumeClaim. One replica with `Recreate`. For PostgreSQL or MySQL:

```yaml
settings:
  DB_DRIVER: postgres
  DB_HOSTNAME: postgres.db
  DB_NAME: kanboard
  DB_USERNAME: kanboard
extraEnvVarsSecret: kanboard-db   # holds DB_PASSWORD
```

Kanboard runs its own migrations on start. Uploaded files stay on the volume.

## Plugins

The plugin installer is off (Kanboard's default). To ship plugins, mount them under
`/var/www/app/plugins` with `extraVolumes` / `extraVolumeMounts`.

## TLS

Kanboard is served over plain HTTP by nginx. With `tls.enabled` a caddy sidecar terminates HTTPS
on 8443 (Service port `service.httpsPort`) and proxies to it over localhost. The certificate comes
from `tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt`
in the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kanboard \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `settings` | `LOG_DRIVER: stderr` | Kanboard environment variables (`DB_*`, ...) |
| `extraEnvVarsSecret` | `""` | Secret with `DB_PASSWORD` and other secrets |
| `persistence.size` | `5Gi` | The data volume |
| `service.port` | `8080` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

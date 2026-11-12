# Quenchworks BookStack

Hardened [BookStack](https://github.com/BookStackApp/BookStack), a wiki and documentation platform,
CVE-gated, cosign-signed and pinned by digest. The image is the release with its composer
dependencies, served by php-fpm 8.4 behind a from-source nginx, on a nonroot Wolfi base. It runs the
database migrations before it serves.

## Install

```bash
helm install bookstack oci://ghcr.io/quenchworks/charts/bookstack --set appUrl=https://docs.example.com
kubectl port-forward svc/bookstack 8080
```

The first start creates the admin `admin@admin.com` with the password `password`. Log in and change
both at once, before the Service is reachable by anyone else. `appUrl` must match the URL in the
browser.

## Database

By default the chart runs the bundled MariaDB subchart. For an external MySQL or MariaDB:

```yaml
mariadb:
  enabled: false
externalDatabase:
  host: mariadb.db
  database: bookstack
  user: bookstack
  existingSecret: bookstack-db
  existingSecretPasswordKey: password
```

An init container waits for the database; the image migrates the schema on every start.

## Storage and keys

One PersistentVolumeClaim holds `storage/` (attachments, logs, caches) and `public/uploads` (images).
`APP_KEY` is generated into the Secret `<fullname>` (`app-key`) and kept across upgrades.

## TLS

BookStack is served over plain HTTP by nginx. With `tls.enabled` a caddy sidecar terminates HTTPS on
8443 (Service port `service.httpsPort`) and proxies to it over localhost; set `appUrl` to the https
address. The certificate comes from `tls.existingSecret`, else a cert-manager `Certificate`, else a
Helm-generated CA (`ca.crt` in the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/bookstack \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `appUrl` | `http://localhost:8080` | The URL users reach BookStack at |
| `appKey.value` / `existingSecret` | generated | `APP_KEY` |
| `settings` | timezone, logs to stderr | More BookStack environment variables |
| `mariadb.enabled` | `true` | Bundled MariaDB |
| `externalDatabase.*` | | External MySQL or MariaDB |
| `persistence.size` | `5Gi` | storage/ and uploads |
| `service.port` | `8080` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

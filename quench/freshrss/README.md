# Quenchworks FreshRSS

Hardened [FreshRSS](https://github.com/FreshRSS/FreshRSS), a self-hosted RSS and Atom aggregator,
CVE-gated, cosign-signed and pinned by digest. The image is the release served by php-fpm 8.4
behind a from-source nginx under supervisord, on a nonroot Wolfi base.

## Install

```bash
helm install freshrss oci://ghcr.io/quenchworks/charts/freshrss --set baseUrl=https://rss.example.com
kubectl port-forward svc/freshrss 8080
```

Log in as `admin` with the generated password:

```bash
kubectl get secret freshrss -o jsonpath='{.data.password}' | base64 -d
kubectl get secret freshrss -o jsonpath='{.data.api-password}' | base64 -d
```

An init container sets up the data volume on first start with FreshRSS's CLI (install with
SQLite and the APIs on, create the admin user), and on every start applies `baseUrl` and the
admin's passwords from the Secret, so the Secret stays the source of truth. More users can be
added in the UI.

## Mobile apps

The Google Reader API is at `<baseUrl>/api/greader.php` (and Fever at `<baseUrl>/api/fever.php`),
with the user name and the API password.

## Feed refresh

A `refresh` sidecar runs `app/actualize_script.php` for every user every
`refresh.intervalMinutes` (20 by default), as upstream's image does from cron.

## Storage

`DATA_PATH` (`/var/www/FreshRSS/data`) holds the config, users, SQLite databases and caches, on a
PersistentVolumeClaim. One replica with `Recreate`.

## TLS

FreshRSS is served over plain HTTP by nginx. With `tls.enabled` a caddy sidecar terminates HTTPS
on 8443 (Service port `service.httpsPort`) and proxies to it over localhost. The certificate comes
from `tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt`
in the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/freshrss \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `baseUrl` | `http://localhost:8080` | The URL users reach FreshRSS at |
| `admin.user` | `admin` | Admin user created on first start |
| `admin.password` / `apiPassword` / `existingSecret` | generated | Web and API passwords |
| `refresh.intervalMinutes` | `20` | Feed refresh interval |
| `persistence.size` | `5Gi` | The data volume |
| `service.port` | `8080` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

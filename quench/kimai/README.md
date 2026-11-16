# Quenchworks Kimai

Hardened [Kimai](https://github.com/kimai/kimai): open-source time tracking for freelancers and teams,
with timesheets, projects, customers, invoices, reports and a REST API. The image runs the release on
Wolfi php-8.5-fpm and QuenchWorks' nginx; it runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest. The chart bundles the QuenchWorks MariaDB chart by default.

## Install

```bash
helm install time oci://ghcr.io/quenchworks/charts/kimai --set settings.DEFAULT_URI=https://time.example.com
kubectl get secret time-kimai -o jsonpath='{.data.admin-password}' | base64 -d   # sign in as admin
```

The pod waits for the database, installs or updates the schema and creates the admin on every start, so
the first start takes a minute.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email`, `admin.password` | `admin`, generated password | The super admin made on the first start |
| `appSecret.value`, `appSecret.existingSecret` | generated | APP_SECRET, kept across upgrades |
| `settings` | `{}` | More environment: TZ, MAILER_FROM, MAILER_URL, DEFAULT_URI, TRUSTED_PROXIES |
| `mariadb.enabled` | `true` | The bundled MariaDB (its own PVC); `false` uses `externalDatabase` |
| `externalDatabase.*` | | host, port, database, user, password or existingSecret, serverVersion |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `5Gi` | var/: cache, logs, sessions, invoices, plugins |

LDAP login is not included in the image (it needs the LDAP PHP extension).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kimai \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

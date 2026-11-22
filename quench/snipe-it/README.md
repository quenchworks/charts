# Quenchworks Snipe-IT

Hardened [Snipe-IT](https://github.com/grokability/snipe-it): IT asset management for hardware, licenses,
accessories and consumables, with check-in and check-out, audits and a REST API. The image runs the release
on Wolfi php-8.5-fpm and QuenchWorks' nginx with Laravel, Livewire and the Symfony http stack raised to
their fixed releases; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.
The chart bundles the QuenchWorks MariaDB chart by default.

## Install

```bash
helm install assets oci://ghcr.io/quenchworks/charts/snipe-it --set appURL=https://assets.example.com
kubectl get secret assets-snipe-it -o jsonpath='{.data.admin-password}' | base64 -d   # sign in as admin
```

The pod waits for the database, migrates, and creates the admin and the site settings on the first start,
so the setup wizard is already done.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email`, `admin.password` | `admin`, generated password | The super admin made on the first start |
| `appKey.value`, `appKey.existingSecret` | generated | APP_KEY (`base64:` + 32 bytes), kept across upgrades. Back it up |
| `appURL`, `siteName` | `""`, `Snipe-IT` | APP_URL and the site name. Since 8.8.4 requests for any other host get 400: use the name users reach it by |
| `settings` | `{}` | More environment: APP_TIMEZONE, MAIL_*, APP_TRUSTED_PROXIES |
| `mariadb.enabled` | `true` | The bundled MariaDB (its own PVC); `false` uses `externalDatabase` |
| `externalDatabase.*` | | host, port, database, user, password or existingSecret |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `5Gi` | storage/ and uploads/ |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/snipe-it \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

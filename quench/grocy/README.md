# Quenchworks Grocy

Hardened [Grocy](https://grocy.info), groceries and household management: stock and expiry tracking,
shopping lists, recipes and meal plans, chores, batteries and equipment, with a barcode-friendly web UI
and a REST API. The image builds the release with composer and yarn on Wolfi PHP 8.5 behind
QuenchWorks' nginx; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install grocy oci://ghcr.io/quenchworks/charts/grocy --set currency=EUR --set tls.enabled=true
kubectl get secret grocy-grocy -o jsonpath='{.data.password}' | base64 -d   # user admin
```

The first user is created with the database from `admin.username` and the generated password, so
Grocy's default `admin`/`admin` account never exists. Grocy reads them once; change the password later
in the UI. Note: the image pins SQLite 3.53.4, because SQLite 3.54.x breaks Grocy's migrations
(grocy/grocy#3010).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The first user |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `currency`, `locale` | `USD`, `en` | `GROCY_CURRENCY`, `GROCY_DEFAULT_LOCALE` |
| `baseURL` | `""` | `GROCY_BASE_URL` behind a proxy |
| `settings` | `{}` | Any other `GROCY_*` setting from config.php |
| `persistence.size` | `5Gi` | config.php, grocy.db and uploads |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/grocy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

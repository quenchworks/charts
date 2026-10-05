# Quenchworks YOURLS

Hardened [YOURLS](https://yourls.org) ("Your Own URL Shortener"): short links with click
statistics, an admin UI and an API. The chart runs YOURLS on PHP-FPM behind nginx on port
8080 with the catalog MariaDB as a subchart. YOURLS keeps links, clicks and options in
the database, so the pods hold no state. On every start an init container runs
`yourls-install`, which waits for the database and creates the tables the first time;
later starts find them and change nothing. The image is minimal, runs nonroot (uid
1001) on a read-only root filesystem with all capabilities dropped, ships 0-CVE, is
cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest, never a
tag.

## Install

`yourls.site` is required: the public base URL the short links are built on.

```bash
helm install links oci://ghcr.io/quenchworks/charts/yourls --set yourls.site=https://sho.rt
kubectl get secret links-yourls -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Point that host at the `links-yourls` Service with an Ingress (`ingress.enabled=true`) or
your own proxy. The admin UI is at `/admin/`.

The admin password, the cookie key and (for an external database) the DB password are
generated on first install and kept on upgrade. `yourls.admin.existingSecret` supplies the
admin password from your own Secret instead.

An existing MySQL or MariaDB:

```yaml
mariadb:
  enabled: false
externalDatabase:
  host: mysql.db.svc
  database: yourls
  user: yourls
  existingSecret: yourls-db
  existingSecretPasswordKey: password
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/yourls \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/yourls --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `yourls.site` | `""` | Required. Public base URL of the short links. |
| `yourls.private` | `true` | Only the admin can shorten; `false` opens a public form and API. |
| `yourls.uniqueUrls` | `true` | One keyword per long URL. |
| `yourls.reservedKeywords` | `[]` | Keywords that never become short links. |
| `yourls.admin.username` / `.password` | `admin` / generated | Or `.existingSecret`. |
| `yourls.cookieKey` | generated | Signs the login cookie. |
| `mariadb.enabled` | `true` | The bundled catalog MariaDB (8Gi PVC). |
| `externalDatabase.*` | | Used when `mariadb.enabled=false`. |
| `replicaCount` | `1` | Stateless; scale freely. |
| `ingress.enabled` | `false` | |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides, security
contexts) work as in every Quenchworks chart.

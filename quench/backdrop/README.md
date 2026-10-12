# Quenchworks Backdrop CMS

Hardened [Backdrop CMS](https://backdropcms.org/), the PHP content-management system
forked from Drupal 7, on a nonroot, read-only-rootfs 0-CVE image pinned by digest and
cosign-signed. A Wolfi PHP-FPM + nginx runtime (supervisord) serves it on port 8080 as
uid 1001.

The chart bundles the Quenchworks MySQL chart and installs Backdrop on the first start:
an init container waits for the database and runs Backdrop's CLI installer
(`core/scripts/install.sh`), which creates the schema, the admin account and the active
config under `files/config/`. On later starts that config exists and the init container
does nothing.

## Install

```bash
helm install site oci://ghcr.io/quenchworks/charts/backdrop \
  --set backdrop.admin.email=you@example.com
kubectl port-forward svc/site-backdrop 8080:8080
# open http://127.0.0.1:8080/user/login and log in as admin
kubectl get secret site-backdrop -o jsonpath='{.data.admin-password}' | base64 -d
```

## Values that matter

| Key | Default | Meaning |
|---|---|---|
| `backdrop.siteName` | `Quench Backdrop` | Site name the installer sets |
| `backdrop.admin.username` / `email` | `admin` / `admin@example.com` | The admin account (uid 1) |
| `backdrop.admin.password` | generated | Used by the installer only |
| `backdrop.hashSalt` | generated | Salt for login links and form tokens |
| `database.prefix` | empty | Optional table prefix |
| `mysql.enabled` | `true` | Bundled MySQL; false uses `externalDatabase.*` (MySQL or MariaDB) |
| `persistence.*` | 10Gi PVC | `files/`: uploads, active and staging config, backups |

## Storage and state

- The image's `settings.php` is read-only and takes the database from `BACKDROP_DB_*`
  env vars, which the chart sets; the password comes from the database Secret, so
  rotating it there and restarting the pod is enough. Mount a `settings.local.php` at
  `/var/www/html/settings.local.php` (extraVolumes + extraVolumeMounts, subPath) for
  other settings.
- `files/` holds the active config as well as uploads, so it is always a PVC and carries
  `helm.sh/resource-policy: keep`: losing it while the database survives leaves a site
  that neither boots nor reinstalls. Delete it by hand together with the database.
- The docroot is read-only. Installing modules, themes or layouts from the admin panel
  writes into it and is not supported; build them into an image.

## Upgrades

A new chart version can move the image to a newer Backdrop. The init container does not
run database updates: after an upgrade, log in as the admin and open `/core/update.php`.

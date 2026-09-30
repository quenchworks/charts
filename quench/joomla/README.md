# Quenchworks Joomla

Hardened [Joomla](https://www.joomla.org/), the PHP content-management system, on a
nonroot, read-only-rootfs 0-CVE image pinned by digest and cosign-signed. A Wolfi
PHP-FPM + nginx runtime (supervisord) serves it on port 8080 as uid 1001.

The chart bundles the Quenchworks MariaDB chart and installs Joomla on the first start:
an init container waits for the database, runs Joomla's CLI installer (the image does
not serve the web installer), creates the super user, and writes `configuration.php` to
a config PVC. On later starts the file exists and the init container does nothing.

## Install

```bash
helm install site oci://ghcr.io/quenchworks/charts/joomla \
  --set joomla.admin.email=you@example.com
kubectl port-forward svc/site-joomla 8080:8080
# open http://127.0.0.1:8080/administrator/ and log in as admin
kubectl get secret site-joomla -o jsonpath='{.data.admin-password}' | base64 -d
```

## Values that matter

| Key | Default | Meaning |
|---|---|---|
| `joomla.siteName` | `Quench Joomla` | Site name the installer sets |
| `joomla.admin.username` / `email` / `name` | `admin` / `admin@example.com` / `Joomla Admin` | The super user |
| `joomla.admin.password` | generated | At least 12 characters; used by the installer only |
| `database.type` | `mysqli` | `mysqli`, `mysql` (PDO) or `pgsql` |
| `database.prefix` | `jos_` | Table prefix, required by Joomla |
| `mariadb.enabled` | `true` | Bundled MariaDB; false uses `externalDatabase.*` |
| `persistence.*` | 10Gi PVC | Media (`images/`, the upload directory) |
| `configPersistence.*` | 128Mi PVC | `configuration.php`; kept on uninstall |

## Storage and state

- `configuration.php` holds the site secret and the database password, so it lives on
  its own PVC, not in a ConfigMap. The PVC carries `helm.sh/resource-policy: keep`:
  losing it while the database survives would make the next start install over a live
  database. Delete it by hand together with the database.
- The installer writes the DB password into `configuration.php`. Rotating the password
  in the Secret afterwards does not change the file; edit it in Global Configuration.
- The docroot is read-only. `tmp`, `cache`, `administrator/cache`, `administrator/logs`
  and `/tmp` are emptyDirs; media is the PVC. Installing extensions from the admin
  panel writes into the docroot and is not supported; build them into an image.

## Upgrades

A new chart version can move the image to a newer Joomla. The init container does not
run schema updates: after an upgrade, open System > Maintenance > Database in the admin
panel and apply Fix if it reports problems.

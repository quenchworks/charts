# Quenchworks Friendica

Hardened [Friendica](https://friendi.ca/), the federated social network server
(ActivityPub, Diaspora, OStatus), on a nonroot, read-only-rootfs 0-CVE image pinned by
digest and cosign-signed. A Wolfi PHP-FPM + nginx runtime (supervisord) serves it on
port 8080 as uid 1001, and runs Friendica's background worker daemon in the same
container.

The chart bundles the Quenchworks MariaDB chart and installs Friendica on the first
start: an init container waits for the database, runs `bin/console.php autoinstall`, and
writes `local.config.php` to a config PVC. On later starts the file exists and the init
container does nothing.

## Install

```bash
helm install social oci://ghcr.io/quenchworks/charts/friendica \
  --set friendica.url=https://social.example.com \
  --set friendica.adminEmail=you@example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=social.example.com' \
  --set networkPolicy.allowExternal=true
```

Then open the site and register an account with `friendica.adminEmail`: that account is
the node administrator. Without an ingress, `kubectl port-forward svc/<release>-friendica
8080:8080` reaches it for a look, but links point at `friendica.url`.

## Values that matter

| Key | Default | Meaning |
|---|---|---|
| `friendica.url` | first ingress host, else the Service | Public base URL. Set it before the first start: federation ids are built from it and do not survive a change |
| `friendica.adminEmail` | `admin@example.com` | The account registered with it is the administrator |
| `friendica.siteName` / `timezone` / `language` | `Quench Friendica` / `UTC` / `en` | Site defaults |
| `mariadb.enabled` | `true` | Bundled MariaDB; false uses `externalDatabase.*` (MySQL or MariaDB) |
| `configPersistence.*` | 128Mi PVC | `local.config.php`; kept on uninstall |
| `networkPolicy.allowExternal` | `false` | Must be true for other servers to reach the node |

## Storage and state

- `local.config.php` holds the database password and the site URL, so it lives on its
  own PVC, not in a ConfigMap. The PVC carries `helm.sh/resource-policy: keep`: losing it
  while the database survives would make the next start install over a live database.
  Delete it by hand together with the database.
- Uploaded photos and files go to the database (Friendica's default "Database" storage
  backend), so the database is the only data to back up. A filesystem backend needs a
  volume mounted through `extraVolumes`/`extraVolumeMounts` and the storage setting in
  the admin panel.
- Both containers get `MYSQL_*` and `FRIENDICA_*` environment variables, which Friendica
  applies over `local.config.php`. A database password rotated in the Secret reaches the
  site on the next pod restart.
- The docroot is read-only. Compiled templates and the worker pidfile live in the `/tmp`
  emptyDir. Addons are not shipped; installing them from the admin panel is not
  supported.

## Image notes

- No ImageMagick: Friendica falls back to GD for images (ImageMagick is a standing CVE
  source).
- The release vendors libraries and browser assets with fixed CVEs. The image floats the
  PHP libraries to fixed releases with composer, and replaces DOMPurify 1.0 with 3.4,
  moment with 2.31 and jQuery 2.2 with 3.7. jQuery Migrate is loaded with it, so the 2.x
  APIs Friendica's scripts call keep working.

## Upgrades

A new chart version can move the image to a newer Friendica. The first request after the
upgrade runs the database update (the site shows a maintenance page meanwhile); the
liveness probe is a TCP check so that update is not interrupted. Friendica supports
upgrades from the previous release only: do not skip a release.

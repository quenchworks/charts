# MediaWiki

[MediaWiki](https://www.mediawiki.org) is the wiki engine behind Wikipedia. This chart
runs it on the QuenchWorks mediawiki image: the official release on a Wolfi
PHP-FPM + nginx runtime, nonroot, read-only rootfs, 0 fixable CVEs, cosign-signed and
pinned by digest.

## Install

```sh
helm install wiki oci://ghcr.io/quenchworks/charts/mediawiki \
  --set mediawiki.server=https://wiki.example.com
kubectl get secret wiki-mediawiki -o jsonpath='{.data.admin-password}' | base64 -d
```

Log in as `Admin` with that password.

## How it starts

The image ships no `LocalSettings.php`. The chart renders one into a ConfigMap and
points `MW_CONFIG_FILE` at it. The wiki's secret key, upgrade key and DB password come
from a managed Secret as env vars; they are kept across upgrades.

Before the wiki container starts, an init container:

1. waits for an external database to answer, if one is configured;
2. runs `maintenance/run.php install` if the `page` table does not exist, which creates
   the schema, the admin account and the Main Page;
3. runs `maintenance/run.php update --quick` every time, so upgrading the chart to a
   newer MediaWiki migrates the schema before the wiki serves.

The installer reads the passwords from files (`--passfile`, `--dbpassfile`), never
from its arguments.

## Values

| Key | Default | Meaning |
|---|---|---|
| `mediawiki.server` | `http://localhost:8080` | `$wgServer`, the URL readers use; absolute links and redirects are built from it |
| `mediawiki.siteName` | `QuenchWiki` | `$wgSitename` |
| `mediawiki.shortUrls` | `true` | `/wiki/Page` URLs |
| `mediawiki.skins` / `extensions` | Vector, MonoBook, Timeless / Cite, ParserFunctions, WikiEditor, CategoryTree, InputBox | bundled skins and extensions to load |
| `mediawiki.extraConfig` | `""` | raw PHP appended to `LocalSettings.php` |
| `mediawiki.admin.password` | `""` | admin password for the installer; empty generates one |
| `database.type` | `sqlite` | `sqlite`, `mysql` or `postgres` |
| `database.host` / `port` / `name` / `user` | | external database; the database and user must exist |
| `database.existingSecret` | `""` | Secret holding the DB password under `existingSecretPasswordKey` |
| `database.sqlite.persistence.size` | `2Gi` | PVC for the SQLite files |
| `persistence.size` | `10Gi` | PVC for uploads (`/var/www/html/images`) |

The chart runs one replica: SQLite and the uploads PVC are ReadWriteOnce, and the
object cache (APCu) is per pod.

## Limits of this image

- **Scribunto** is bundled but can't run: its prebuilt Lua binaries were removed
  (x86_64 and i386 only, unscannable), and Wolfi packages no Lua 5.1.
- **ImageMagick** is not included; thumbnails use GD.
- **Mail** is off until you set `$wgSMTP` in `mediawiki.extraConfig`.
- The vendored `guzzlehttp/guzzle` (and `web-auth/webauthn-lib` on 1.46) are floated
  to their fixed releases in the image, with the root `composer.json` pins moved so
  `update.php` accepts them.

## Release gate

On kind, the gate installs the chart on SQLite. It logs in as the admin through the
API, saves a page containing a ParserFunctions call, and requires the rendered page.
It deletes the pod and requires the new one to find the schema and still serve the
page. Then it installs the chart again against the quench mysql chart and repeats the
login and edit.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

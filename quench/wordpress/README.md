# Quenchworks WordPress

Hardened [WordPress](https://wordpress.org/) — the PHP content-management system — on a
minimal, nonroot, **read-only-rootfs** 0-CVE image pinned by digest and cosign-signed.
WordPress is served by a Wolfi **PHP-FPM + nginx** runtime (supervisord): nginx listens on
`8080` (nonroot can't bind `<1024`) and FastCGI-passes `.php` to php-fpm on
`127.0.0.1:9000`. It runs as uid `1001`.

WordPress needs an external **MySQL/MariaDB**. This chart bundles the Quenchworks MySQL
chart by default, provisions an uploads PVC at `wp-content/uploads`, and supplies the
`wp-config.php` the image intentionally omits — that config reads every DB setting and auth
salt from environment variables injected from a managed Secret, so no secret is ever baked
into the image or written to disk.

## Install

```bash
# self-contained: bundles in-cluster MySQL + an uploads PVC
helm install blog oci://ghcr.io/quenchworks/charts/wordpress \
  --set mysql.auth.rootPassword="ChangeMeRoot" \
  --set mysql.auth.password="ChangeMe"
```

Then finish the famous five-minute install at `/wp-admin/install.php`. The DB password and
WordPress auth salts are injected from a managed Secret as `WORDPRESS_*` env vars and read
by `wp-config.php`, so they never appear in the pod's process arguments.

## Connect

```bash
kubectl port-forward svc/blog-wordpress 8080:8080
# site:    http://localhost:8080/
# install: http://localhost:8080/wp-admin/install.php
# admin:   http://localhost:8080/wp-admin/
```

## Database

By default the bundled Quenchworks MySQL subchart is deployed; its primary Service is
`<release>-mysql` on port `3306`. The MySQL image creates `mysql.auth.database` and the
`mysql.auth.username`/`password` on first init, and WordPress connects with them. Set
`mysql.auth.rootPassword` and `mysql.auth.password` for a deterministic install.

To use an external MySQL/MariaDB, set `mysql.enabled=false` and fill in
`externalDatabase.*` (or `externalDatabase.existingSecret` carrying the password key).

## wp-config.php & the read-only rootfs

The image ships **no** `wp-config.php` (with none present it just serves the setup wizard).
The chart mounts one from a ConfigMap at `/var/www/html/wp-config.php` (read-only, subPath).
It resolves the DB connection and the eight auth keys/salts from the pod environment at
request time (php-fpm runs with `clear_env=no`).

The rootfs is **read-only**: WordPress core, themes and plugins are baked into the signed
image, and only `wp-content/uploads` (a PVC) and `/tmp` (emptyDir) are writable. In-dashboard
core/plugin/theme edits and updates are therefore disabled (`DISALLOW_FILE_MODS`) — rebuild
the image to change code. Auth salts are generated once and persisted in the Secret, so
upgrades don't log everyone out.

## Security

`/wp-admin` is password-protected, but the public site is meant for readers. By default
`networkPolicy.allowExternal` is `false`, restricting ingress to the release namespace.
Front WordPress with an ingress/TLS proxy and set `allowExternal=true` to expose it; set
`wordpress.siteUrl` so WordPress builds correct absolute URLs behind the proxy.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/wordpress \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/wordpress` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `wordpress.siteUrl` | `""` | Pin `WP_HOME`/`WP_SITEURL` (behind a proxy); optional |
| `wordpress.tablePrefix` | `wp_` | Database table prefix |
| `replicaCount` | `1` | Replicas (uploads PVC is ReadWriteOnce) |
| `service.port` | `8080` | Public site + `/wp-admin` port |
| `persistence.enabled` | `true` | Provision the uploads PVC |
| `persistence.size` | `10Gi` | Uploads PVC size |
| `persistence.mountPath` | `/var/www/html/wp-content/uploads` | Uploads mount path |
| `mysql.enabled` | `true` | Deploy the bundled MySQL backend |
| `mysql.auth.database` | `wordpress` | App database |
| `mysql.auth.username` | `wordpress` | DB user |
| `networkPolicy.allowExternal` | `false` | Allow ingress from outside the namespace |

# Quenchworks Drupal

Hardened [Drupal](https://www.drupal.org/), the PHP content-management system, on a
minimal, nonroot, read-only-rootfs 0-CVE image pinned by digest and cosign-signed. Drupal
is served by a Wolfi PHP-FPM + nginx runtime (supervisord): nginx listens on `8080`
(nonroot can't bind `<1024`) and FastCGI-passes `.php` to php-fpm on `127.0.0.1:9000`, with
`/opt/drupal` as the docroot. It runs as uid `1001`.

Drupal needs an external MySQL/MariaDB. This chart bundles the Quenchworks MySQL chart by
default, provisions a public-files PVC at `sites/default/files`, and supplies the
`settings.php` the image intentionally omits. That config reads every DB setting and the
hash salt from environment variables injected from a managed Secret, so no secret is ever
baked into the image or written to disk.

## Install

```bash
# self-contained: bundles in-cluster MySQL + a files PVC
helm install cms oci://ghcr.io/quenchworks/charts/drupal \
  --set mysql.auth.rootPassword="ChangeMeRoot" \
  --set mysql.auth.password="ChangeMe"
```

Then finish the install at `/core/install.php`. The DB password and hash salt are injected
from a managed Secret as `DRUPAL_*` env vars and read by `settings.php`, so they never appear
in the pod's process arguments.

## Connect

```bash
kubectl port-forward svc/cms-drupal 8080:8080
# site:    http://localhost:8080/
# install: http://localhost:8080/core/install.php
# admin:   http://localhost:8080/admin
```

## Database

By default the bundled Quenchworks MySQL subchart is deployed; its primary Service is
`<release>-mysql` on port `3306`. The MySQL image creates `mysql.auth.database` and the
`mysql.auth.username`/`password` on first init, and Drupal connects with them. Set
`mysql.auth.rootPassword` and `mysql.auth.password` for a deterministic install.

To use an external MySQL/MariaDB, set `mysql.enabled=false` and fill in `externalDatabase.*`
(or `externalDatabase.existingSecret` carrying the password key). For an external PostgreSQL,
also set `extraEnvVars: [{name: DRUPAL_DB_DRIVER, value: pgsql}]` (the image ships the
`pdo_pgsql` driver).

## settings.php & the read-only rootfs

The image ships no `sites/default/settings.php` (with none present it redirects `/` to
the installer). The chart mounts one from a ConfigMap at
`/opt/drupal/sites/default/settings.php` (read-only, subPath). It resolves the DB connection
and the hash salt from the pod environment at request time (php-fpm runs with `clear_env=no`).

The rootfs is read-only: Drupal core, modules and themes are baked into the signed image,
and only `sites/default/files` (a PVC) and `/tmp` (emptyDir) are writable. In-place UI updates
are therefore closed; rebuild the image to change code. The hash salt is generated once and
persisted in the Secret, so upgrades don't invalidate sessions.

## Security

`/admin` and the installer are password-protected, but the public site is meant for readers.
By default `networkPolicy.allowExternal` is `false`, restricting ingress to the release
namespace. Front Drupal with an ingress/TLS proxy and set `allowExternal=true` to expose it;
set `drupal.trustedHostPatterns` so Drupal only serves your hostnames.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/drupal \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/drupal --owner quenchworks`.

## Key values

| Key                           | Default                             | Description                                                                               |
| ----------------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/drupal` | Image repo                                                                                |
| `image.digest`                | pinned `sha256:…`                   | Immutable image digest (CI-maintained)                                                    |
| `drupal.trustedHostPatterns`  | `[]`                                | Host header patterns Drupal serves (behind a proxy)                                       |
| `drupal.tablePrefix`          | `""`                                | Database table prefix                                                                     |
| `replicaCount`                | `1`                                 | Replicas (files PVC is ReadWriteOnce)                                                     |
| `service.port`                | `8080`                              | Public site + `/admin` + installer port                                                   |
| `persistence.enabled`         | `true`                              | Provision the files PVC                                                                   |
| `persistence.size`            | `10Gi`                              | Files PVC size                                                                            |
| `persistence.mountPath`       | `/opt/drupal/sites/default/files`   | Files mount path                                                                          |
| `mysql.enabled`               | `true`                              | Deploy the bundled MySQL backend                                                          |
| `mysql.auth.database`         | `drupal`                            | App database                                                                              |
| `mysql.auth.username`         | `drupal`                            | DB user                                                                                   |
| `networkPolicy.allowExternal` | `false`                             | Allow ingress from outside the namespace                                                  |
| `ingress.enabled`             | `false`                             | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                              | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

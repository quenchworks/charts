# Quenchworks Nextcloud

Hardened [Nextcloud](https://nextcloud.com/) — the self-hosted content-collaboration and
file-sync platform — on a minimal, nonroot, 0-CVE image pinned by digest and cosign-signed.
The image is a clean-room Wolfi rebuild (php-fpm + the QuenchWorks nginx, supervised by
supervisord) of the official upstream release tarball; it runs as uid `1001` and serves
HTTP on port `8080`.

> **License:** Nextcloud Server is **AGPL-3.0-only** — strong copyleft, where network use
> counts as distribution. If you modify the source and offer it over a network you must make
> your modified source available. The image ships the unmodified upstream release.

Nextcloud keeps all durable relational state (accounts, shares, metadata) in an external
**MySQL/MariaDB**; user files live under `/var/www/html/data` and the instance config under
`/var/www/html/config`, both on `ReadWriteOnce` PVCs. This chart bundles the Quenchworks
MariaDB chart by default. It can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster MariaDB + data/config PVCs
helm install cloud oci://ghcr.io/quenchworks/charts/nextcloud \
  --set nextcloud.trustedDomains[0]="cloud.example.com" \
  --set nextcloud.admin.password="ChangeMeAdmin" \
  --set mariadb.auth.rootPassword="ChangeMeRoot" \
  --set mariadb.auth.password="ChangeMe"
```

The image's entrypoint does **not** self-install. An `install` initContainer runs
`occ maintenance:install` once — writing `config.php` and creating the schema — before the
app container serves; it retries while the bundled MariaDB comes up, so first boot can take
a couple of minutes (a startup probe gates it). The admin and DB passwords are injected from
a managed Secret via `secretKeyRef`, so they never appear in the pod's process arguments.

## Connect

```bash
kubectl port-forward svc/cloud-nextcloud 8080:8080
# open http://localhost:8080/  (localhost/127.0.0.1 are trusted by default)

# admin password (if generated):
kubectl get secret cloud-nextcloud -o jsonpath='{.data.admin-password}' | base64 -d
```

## Trusted domains

Nextcloud returns **400 "Access through untrusted domain"** for any request whose `Host` is
not in `nextcloud.trustedDomains` (default `["localhost", "127.0.0.1"]`). Add the address
users actually reach Nextcloud at, and set `nextcloud.overwriteProtocol=https` when a TLS
proxy/ingress terminates in front of the plain-HTTP pod. The list is (re)applied on every
boot as a `config/trusted.config.php` overlay.

## Database

By default the bundled Quenchworks MariaDB subchart is deployed; its primary Service is
`<release>-mariadb` on port `3306`. The MariaDB image creates `mariadb.auth.database` and
the `mariadb.auth.username`/`password` on first init, and Nextcloud is installed against
them. Set `mariadb.auth.rootPassword` and `mariadb.auth.password` for a deterministic
install.

To use an external MySQL/MariaDB, set `mariadb.enabled=false` and fill in
`externalDatabase.*` (or `externalDatabase.existingSecret` carrying the password key). The
admin password is still generated into the managed Secret.

## Storage

Two `ReadWriteOnce` PVCs back the writable, must-survive-restart paths on the read-only
rootfs: `/var/www/html/data` (user files) and `/var/www/html/config` (`config.php` +
overlays). The writable app-store dir `/var/www/html/custom_apps` and `/tmp` are ephemeral
emptyDirs; the bundled apps under the read-only `/var/www/html/apps` persist in the image.

## Security

By default `networkPolicy.allowExternal` is `false`, restricting ingress to the release
namespace. Front Nextcloud with an ingress/TLS proxy and set `allowExternal=true` to expose
it. The container keeps the hardened defaults: nonroot uid `1001`, dropped capabilities,
`allowPrivilegeEscalation=false`, and a **read-only root filesystem** (the image is designed
for it — only the mounted volumes are writable).

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/nextcloud \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/nextcloud` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `nextcloud.admin.username` | `admin` | Admin account created on install |
| `nextcloud.admin.password` | generated | Admin password (managed Secret if empty) |
| `nextcloud.trustedDomains` | `[localhost, 127.0.0.1]` | Hosts Nextcloud answers for |
| `nextcloud.overwriteProtocol` | `http` | Protocol for generated URLs (`https` behind TLS) |
| `replicaCount` | `1` | Replicas (PVCs are ReadWriteOnce) |
| `service.port` | `8080` | HTTP port (image nginx, nonroot) |
| `persistence.data.size` | `10Gi` | User-file PVC size (`/var/www/html/data`) |
| `persistence.config.size` | `1Gi` | Config PVC size (`/var/www/html/config`) |
| `mariadb.enabled` | `true` | Deploy the bundled MariaDB backend |
| `mariadb.auth.database` | `nextcloud` | App database |
| `mariadb.auth.username` | `nextcloud` | DB user |
| `networkPolicy.allowExternal` | `false` | Allow ingress from outside the namespace |

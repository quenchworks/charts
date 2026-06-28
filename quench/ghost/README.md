# Quenchworks Ghost

Hardened [Ghost](https://ghost.org/) — the Node.js publishing platform (CMS, membership
and newsletter engine) — on a minimal, nonroot, 0-CVE image pinned by digest and
cosign-signed. Ghost runs as uid `1001` and serves the public site **and** the `/ghost`
admin on port `2368`.

Ghost is configured **entirely by environment variables** (it reads `__`-nested config
keys, e.g. `database__connection__host`) and needs an external **MySQL/MariaDB**. This
chart bundles the Quenchworks MariaDB chart by default and provisions a content PVC at
`/var/lib/ghost/content` for themes, images, uploads, data and logs. It can also point at
an external database.

## Install

```bash
# self-contained: bundles in-cluster MariaDB + a content PVC
helm install blog oci://ghcr.io/quenchworks/charts/ghost \
  --set ghost.url="https://blog.example.com" \
  --set mariadb.auth.rootPassword="ChangeMeRoot" \
  --set mariadb.auth.password="ChangeMe"
```

`ghost.url` is **required** — Ghost derives every absolute link, canonical URL,
RSS/sitemap entry and admin redirect from it. The DB password is injected from a managed
Secret as `database__connection__password`, so it never appears in the pod's process
arguments.

## Connect

```bash
kubectl port-forward svc/blog-ghost 2368:2368
# site:  http://localhost:2368/
# admin: http://localhost:2368/ghost/
```

## Database

By default the bundled Quenchworks MariaDB subchart is deployed; its primary Service is
`<release>-mariadb` on port `3306`. The MariaDB image creates `mariadb.auth.database` and
the `mariadb.auth.username`/`password` on first init, and Ghost connects with them. Set
`mariadb.auth.rootPassword` and `mariadb.auth.password` for a deterministic install.

To use an external MySQL/MariaDB, set `mariadb.enabled=false` and fill in
`externalDatabase.*` (or `externalDatabase.existingSecret` carrying the password key).

## Content store & the seed initContainer

A `ReadWriteOnce` PVC is mounted at `/var/lib/ghost/content`. The Ghost image **ships its
default themes** (the active `source` theme) inside that exact path, so mounting an empty
PVC over it would hide them and Ghost would 500 with *"active theme 'source' is missing"*.

To avoid that, a `seed-content` initContainer runs the **same Ghost image** but mounts the
PVC at `/seed` (not at `/var/lib/ghost/content`). Because the mount is at a different path,
the image's built-in `/var/lib/ghost/content` is **not shadowed** inside the init
container, so it can copy from there onto the volume:

```sh
cp -an /var/lib/ghost/content/. /seed/ 2>/dev/null || true
```

`cp -an` is no-clobber, so existing user content is never overwritten on restarts — only
missing default files are added.

## Security

Ghost's `/ghost` admin is password-protected, but the public site is meant for readers.
By default `networkPolicy.allowExternal` is `false`, restricting ingress to the release
namespace. Front Ghost with an ingress/TLS proxy and set `allowExternal=true` to expose it.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/ghost \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/ghost` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `ghost.url` | `http://localhost:2368` | Public site URL (**required**) |
| `replicaCount` | `1` | Ghost replicas (content PVC is ReadWriteOnce) |
| `service.port` | `2368` | Public site + `/ghost` admin port |
| `persistence.enabled` | `true` | Provision the content PVC |
| `persistence.size` | `10Gi` | Content PVC size |
| `persistence.mountPath` | `/var/lib/ghost/content` | Content mount path |
| `mariadb.enabled` | `true` | Deploy the bundled MariaDB backend |
| `mariadb.auth.database` | `ghost` | App database |
| `mariadb.auth.username` | `ghost` | DB user |
| `networkPolicy.allowExternal` | `false` | Allow ingress from outside the namespace |

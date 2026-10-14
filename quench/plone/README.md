# Plone

[Plone](https://plone.org) is an enterprise content-management system on Zope. This
chart runs the Plone 6 backend: `Products.CMFPlone` with
[plone.restapi](https://plonerestapi.readthedocs.io), the REST API a Volto frontend (or
any client) talks to. It does not include the Volto frontend. The QuenchWorks plone
image runs as a single-replica StatefulSet with the ZODB on a PVC; it is nonroot,
cosign-signed and pinned by digest.

## Install

```sh
helm install plone oci://ghcr.io/quenchworks/charts/plone
kubectl port-forward svc/plone 8080:8080
curl -H 'Accept: application/json' http://127.0.0.1:8080/Plone/++api++
```

The first boot adds the Zope admin user and creates the site (`site.id`, default
`Plone`) through plone.distribution, then starts the server; the startup probe allows
10 minutes for it. Later boots reuse the site.

## Admin user

`admin.user` (default `admin`) is a Zope Manager created on first boot. The chart
generates its password once and keeps it across upgrades; read it with:

```sh
kubectl get secret plone -o jsonpath='{.data.admin-password}' | base64 -d
```

Bring your own with `admin.existingSecret` / `admin.existingSecretKey`. The password is
only set when the user is created; change it later in Plone.

## Site

`site.distribution` picks the plone.distribution profile: `volto` (default, the
headless site for a Volto frontend) or `classic` (server-rendered Classic UI).
`site.title`, `site.language`, `site.timezone` and `site.exampleContent` feed the site
creation form. An empty `site.id` skips site creation.

## Storage

By default the ZODB is a FileStorage: `/data/filestorage/Data.fs` and
`/data/blobstorage/` on the PVC. One Data.fs means one writer, so keep `replicaCount`
at 1.

For RelStorage on PostgreSQL, create a Secret holding a libpq-style DSN and point
`relstorage.existingSecret` at it:

```sh
kubectl create secret generic plone-db --from-literal=dsn='host=pg dbname=plone user=plone password=...'
helm install plone oci://ghcr.io/quenchworks/charts/plone --set relstorage.existingSecret=plone-db
```

Objects and blobs then live in the database (pg8000 driver, history-free by default;
`PLONE_RELSTORAGE_KEEP_HISTORY=true` through `extraEnvVars` keeps history) and the PVC
holds only the blob cache.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.user` | `admin` | Zope admin user created on first boot |
| `admin.existingSecret` | `""` | your own Secret for its password |
| `site.id` | `Plone` | site created on first boot (empty: none) |
| `site.distribution` | `volto` | `volto` or `classic` |
| `relstorage.existingSecret` | `""` | Secret with a PostgreSQL DSN for RelStorage |
| `threads` | `4` | waitress worker threads |
| `cacheSize` | `30000` | ZODB object cache size per connection |
| `persistence.enabled` | `true` | PVC for /data |
| `persistence.size` | `5Gi` | PVC size |
| `service.port` | `8080` | Service port |
| `ingress.enabled` | `false` | an Ingress for the API |
| `networkPolicy.enabled` | `true` | restrict ingress to the namespace |
| `networkPolicy.allowExternal` | `false` | allow ingress from any source |

Pods run with a read-only root filesystem and all capabilities dropped; `/tmp` is an
emptyDir (the rendered `zope.conf` and `zope.ini`, and the upload spool).

The release gate installs the chart on kind with persistence on, reads the site from
`/Plone/++api++` anonymously, creates a Document through the REST API as the admin,
deletes the pod and reads the Document back after it restarts.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

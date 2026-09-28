# Odoo Community Edition

[Odoo](https://www.odoo.com) Community Edition is the open-source (LGPL-3.0) ERP and
business apps suite: CRM, sales, inventory, invoicing, project, website and more. This
chart runs it on the QuenchWorks odoo image: the nightly source on Wolfi Python 3.13
with its dependencies at their newest releases, nonroot, read-only root filesystem, 0
fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install erp oci://ghcr.io/quenchworks/charts/odoo
kubectl get secret erp-odoo -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/erp-odoo 8069
```

Log in at http://127.0.0.1:8069 as `admin` with that password.

## What the chart does

- An init container waits for PostgreSQL, installs `initModules` (default `base`) into
  the empty database once, and replaces upstream's default `admin` password with the
  generated one. On later starts it sees an initialised database and does nothing.
- The server runs with `--no-database-list`, so the database manager (create, drop,
  backup and restore over HTTP) is off and the release serves one database.
- The filestore (attachments, images) and sessions live on a PVC at `/data`.

Install more apps from the Apps menu, or list them in `initModules` for a fresh
database. Upgrading modules after an Odoo update is not automatic: run the server once
with `-u all` (for example through `extraArgs`) or from a one-off Job.

## Values

| Key | Default | Meaning |
|---|---|---|
| `adminPassword.value` / `.existingSecret` | generated | the `admin` user's password |
| `initModules` | `base` | modules installed into an empty database |
| `demoData` | `false` | install demo data |
| `proxyMode` | `false` | trust `X-Forwarded-*` from an ingress |
| `workers` | `0` | multi-process mode; 0 is the threaded server |
| `postgresql.enabled` | `true` | the bundled PostgreSQL; `false` uses `externalDatabase.*` |
| `persistence.*` | `8Gi` PVC | the filestore and sessions |

With `workers` above 0, Odoo serves the websocket (live chat, notifications) on a
separate gevent port; route `/websocket` to it yourself. The threaded server serves
everything on 8069.

PDF reports need wkhtmltopdf, which the image does not include. Odoo still renders the
HTML version of every report.

The release gate installs the chart on kind, checks the version and `/web/health`, logs
in with the generated password, requires the default `admin` password to fail, reads
the user back from PostgreSQL, and restarts the pod to confirm the init container
leaves an initialised database alone.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

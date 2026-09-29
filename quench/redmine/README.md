# Redmine

[Redmine](https://www.redmine.org) is the open-source (GPL-2.0) project management and
issue tracker: issues, wikis, time tracking, Gantt charts, repositories and a REST API.
This chart runs it on the QuenchWorks redmine image: the release tarball on Wolfi Ruby
4.0 with every gem compiled against Wolfi's libxml2, libxslt and libpq, nonroot,
read-only root filesystem, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install pm oci://ghcr.io/quenchworks/charts/redmine
kubectl get secret pm-redmine -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/pm-redmine 3000
```

Log in at http://127.0.0.1:3000 as `admin` with that password.

## What the chart does

- An init container waits for PostgreSQL and migrates the schema. Into an empty database
  it also loads the default data (trackers, statuses, roles, in `defaultDataLang`) and
  replaces upstream's `admin`/`admin` with the generated password, with no forced change
  at first login. An initialised database keeps its data and its admin password.
- `SECRET_KEY_BASE` is generated once and kept across upgrades, so sessions survive.
- Attachments live on a PVC at `/data/files`; tmp, logs (to stdout) and plugin assets
  live under `/tmp`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `adminPassword.value` / `.existingSecret` | generated | the `admin` user's password |
| `secretKeyBase.value` / `.existingSecret` | generated | signs sessions and cookies |
| `defaultDataLang` | `en` | language of the default data |
| `restApi` | `false` | turn the REST API on |
| `configurationYml` | `""` | contents of `config/configuration.yml` (email delivery, attachments, SCM) |
| `postgresql.enabled` | `true` | the bundled PostgreSQL; `false` uses `externalDatabase.*` |
| `persistence.*` | `8Gi` PVC | attachments under `/data/files` |

Email needs `configurationYml`: Redmine reads delivery settings only from that file, and
upstream ships none. Thumbnails of image attachments need ImageMagick, which the image
does not include. PostgreSQL is the only database this image is built for.

The release gate installs the chart on kind, checks the version and `/login`, calls the
REST API as the admin with the generated password and requires `admin`/`admin` to fail,
reads the user back from PostgreSQL, and restarts the pod to confirm the init container
leaves an initialised database alone.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

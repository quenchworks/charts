# pgAdmin

[pgAdmin 4](https://www.pgadmin.org) is the web administration and development UI for
PostgreSQL: the query tool, ERD, schema diff, and backup and restore through `pg_dump`
and `pg_restore`. This chart runs it in server mode on the QuenchWorks pgadmin image.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest, and takes its
native libraries (libpq, OpenSSL, the image libraries) from Wolfi rather than from the
self-bundling Python wheels, so every one of them is scanned.

## Install

```sh
helm install pgadmin oci://ghcr.io/quenchworks/charts/pgadmin --set admin.email=you@example.com
kubectl get secret pgadmin -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/pgadmin 5050:5050
```

The first start on an empty volume creates the admin. Accounts, saved servers and
preferences live in a SQLite file on the PVC. Any `config.py` key goes in `config`, which
the image reads from `PGADMIN_CONFIG_<KEY>` environment variables:

```yaml
config:
  MAX_LOGIN_ATTEMPTS: 5
  AUTHENTICATION_SOURCES: ["oauth2", "internal"]
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.email` | `admin@example.com` | first administrator |
| `admin.password` | generated | or `admin.existingSecret` (key `admin-password`) |
| `config` | `{}` | `config.py` keys (strings, numbers, booleans, lists) |
| `persistence.size` | `2Gi` | the pgAdmin data directory |

One replica: pgAdmin keeps its accounts and sessions in SQLite on a ReadWriteOnce volume.
Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the QuenchWorks PostgreSQL chart and this chart on kind, signs
in as the admin, registers that PostgreSQL and connects to it, lists its databases,
recreates the pgAdmin pod and requires the saved server to still be there.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

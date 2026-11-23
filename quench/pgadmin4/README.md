# pgAdmin 4

[pgAdmin 4](https://www.pgadmin.org), the web administration and development platform for PostgreSQL: query tool,
schema browser, backup and restore (the PostgreSQL 18 client tools are in the image). It runs in server mode under
gunicorn with its config database (SQLite) on a volume. The image is built from source by QuenchWorks, CVE-gated,
signed with cosign and pinned by digest.

## Install

```sh
helm install pgadmin oci://ghcr.io/quenchworks/charts/pgadmin4 --set admin.email=you@example.com
kubectl get secret pgadmin-pgadmin4 -o jsonpath='{.data.admin-password}' | base64 -d
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.email`, `admin.password` | `admin@example.com`, generated | The first user, created on the first start. |
| `secret.existingSecret` | `""` | Secret with `admin-password` instead. |
| `servers` | `[]` | Servers pre-registered for that user on the first start (servers.json fields: `Name`, `Host`, `Port`, `Username`, ...). |
| `config` | `{}` | pgAdmin config values, each passed as `PGADMIN_CONFIG_<NAME>` (Python literals). |
| `persistence.*` | 1Gi RWO | The config DB, sessions and file storage. One replica (SQLite). |
| `tls.enabled` | `false` | gunicorn serves HTTPS on 8080 (existing Secret, cert-manager, or a Helm-made CA). |

Saved server passwords are encrypted with a master password the user sets after signing in, unless
`config.MASTER_PASSWORD_REQUIRED: "False"`.

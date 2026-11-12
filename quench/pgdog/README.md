# Quenchworks PgDog

Hardened [PgDog](https://github.com/pgdogdev/pgdog), the PostgreSQL connection pooler, load
balancer and sharding proxy in Rust. The image is built from source with cargo auditable,
runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

PgDog is AGPL-3.0. Running it unmodified, as this chart does, needs nothing from you; if you
change its source and offer it to users over a network, the AGPL asks you to publish your
changes.

## Install

```yaml
# my-values.yaml
databases:
  - name: app
    host: postgres.default.svc.cluster.local
    port: 5432
users:
  - name: app
    database: app
    password: change-me
```

```bash
helm install pgdog oci://ghcr.io/quenchworks/charts/pgdog -f my-values.yaml
```

Clients connect to `pgdog:6432` with a user and database from `users`; PgDog pools their
transactions over server connections to the database's `host`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `databases` | `[]` | `[[databases]]` entries: `name`, `host`, `port`, `database_name`, `role` (`primary`/`replica`), `shard` |
| `users` | `[]` | `[[users]]` entries: `name`, `database`, `password` |
| `existingUsersSecret` | `""` | A Secret with your own `users.toml` instead of `users` |
| `general` | workers 2, pool 10, transaction mode | Extra `[general]` settings |
| `admin.password` | random, kept across upgrades | Password for the `admin` user on the `admin` database |
| `extraConfig` | `""` | Raw TOML appended to `pgdog.toml` (sharding, plugins) |
| `metrics.enabled` | `true` | OpenMetrics on port 9090 |

Both files live in a Secret, since they carry passwords; changing values rolls the pods.

## TLS

`tls.enabled: true` sets `tls_certificate` and `tls_private_key` to a certificate mounted at
`/tls`, from `tls.existingSecret`, a cert-manager Certificate, or a Helm-generated self-signed
CA. Clients then connect with `sslmode=require` (or `verify-full` against the CA in the
Secret's `ca.crt`). Add `general.tls_client_required: true` to refuse plaintext clients.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pgdog \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

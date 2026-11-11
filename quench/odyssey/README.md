# Quenchworks Odyssey

Hardened [Odyssey](https://github.com/yandex/odyssey), Yandex's multi-threaded PostgreSQL
connection pooler: many client connections share a small pool of server connections, in session,
transaction or statement mode. It is an alternative to PgBouncer for high connection counts.

The image is built from the upstream release tag (C, CMake) against Wolfi OpenSSL, runs as nonroot
uid 1001, is CVE-gated (the build fails on any fixable CVE), and is cosign-signed and pinned by
digest. It is built without PAM and LDAP authentication.

## Install

```bash
kubectl create secret generic app-db --from-literal=password=<app's password>
helm install pool oci://ghcr.io/quenchworks/charts/odyssey \
  --set postgres.host=my-postgres \
  --set 'users[0].name=app' --set 'users[0].existingSecret=app-db'
# apps connect to pool-odyssey:6432 as app, any database
```

Each listed user's password authenticates the client (SCRAM-SHA-256) and logs in to PostgreSQL as
the same role, so it must match the role's password. Users that are not listed are refused.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/odyssey \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/odyssey@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/odyssey` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `1` | Each replica keeps its own pools. |
| `postgres.host` / `port` | `""` / `5432` | The PostgreSQL server pooled to. |
| `users` | `[]` | `{name, password}` or `{name, existingSecret, existingSecretKey}`; unlisted users are refused. |
| `pool.mode` | `transaction` | `session`, `transaction` or `statement`. |
| `pool.size` | `20` | Server connections per user and database (0: unlimited). |
| `pool.discard` | `true` | `DISCARD ALL` before a connection goes back to the pool. |
| `workers` | `2` | Odyssey worker threads. |
| `port` / `service.port` | `6432` / `6432` | |
| `extraConfig` | `""` | Raw lines appended to the global section of `odyssey.conf`. |
| `tls.enabled` | `false` | Require TLS from clients with the chart's certificate. |
| `networkPolicy.enabled` / `allowExternal` | `true` / `false` | Ingress to the pooler port from the namespace. |
| `resources` | 50m / 64Mi requests, 2 CPU / 512Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **The config is a Secret.** `odyssey.conf` carries the user passwords; passwords from
  `existingSecret` are read when the chart is installed or upgraded, so rotate them with
  `helm upgrade`.
- **One route per listed user** under `database default`, so any database name works and nothing
  else gets in.
- **Probes** open a TCP connection to the pooler port. Odyssey's Prometheus endpoint needs
  libraries this build leaves out.
- **TLS** is `tls "require"` on the listener; plain clients are refused.

Odyssey is BSD-3-Clause licensed.

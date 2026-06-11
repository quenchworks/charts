# Quenchworks MariaDB

Hardened MariaDB on a minimal, nonroot, 0-CVE image pinned by digest. The image runs
`mariadb-install-db` on first boot, applies setup via a temporary local server, then
serves; the chart pins it by the signed digest.

## Install

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb
```

Set your own root password and create an application database + user:

```bash
helm install my-mariadb oci://ghcr.io/quenchworks/charts/mariadb \
  --set auth.rootPassword='change-me' \
  --set auth.database='myapp' \
  --set auth.username='app' --set auth.password='app-pass'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mariadb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mariadb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.rootPassword` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional application database created on first boot. |
| `auth.username` / `auth.password` | `""` | Optional application user (password generated if empty). |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/mysql`. |
| `service.port` | `3306` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/mysql`, the socket dir, and `/tmp` are writable.

## Notes

Single primary for now. Galera/replication topologies, a metrics exporter sidecar, and
custom `my.cnf` tuning are tracked as follow-ups. Depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

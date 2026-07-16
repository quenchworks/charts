# Quenchworks PostgreSQL

Hardened PostgreSQL on a minimal, nonroot, 0-CVE image pinned by digest. The image
runs `initdb` on first boot, then serves; the chart pins it by the signed digest.

## Install

```bash
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql
```

By default auth is on and a superuser password is generated into a Secret. To set
your own and create an application database:

```bash
helm install my-pg oci://ghcr.io/quenchworks/charts/postgresql \
  --set auth.password='change-me' \
  --set auth.database='myapp'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgresql \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/postgresql \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/postgresql` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.enabled` | `true` | PostgreSQL needs a superuser password to initialize. |
| `auth.username` | `postgres` | Superuser created by initdb. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional extra database created on first boot. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC; PGDATA lives in a subdir of it. |
| `primary.shmVolume.enabled` | `true` | Memory-backed `/dev/shm` for parallel queries. |
| `service.port` | `5432` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. PGDATA, the socket dir, `/tmp`, and `/dev/shm` are the only writable mounts.

## Notes

Single primary for now. Streaming replication, a metrics exporter sidecar, and custom
`postgresql.conf` tuning are tracked as follow-ups. The chart depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

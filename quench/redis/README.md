# Quenchworks Redis

Hardened Redis on a minimal, nonroot, 0-CVE image pinned by digest.

## Install

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis
```

By default auth is on and a password is generated into a Secret. To set your own:

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis \
  --set auth.password='change-me'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/redis \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/redis` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.enabled` | `true` | Sets `--requirepass`. |
| `auth.password` | `""` | Generated if empty. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `persistence.enabled` | `true` | 8Gi PVC by default. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Notes

The chart depends on the `quench-common` library chart, vendored in this repo for now. The image
runs as nonroot on a read-only root filesystem with all capabilities dropped.

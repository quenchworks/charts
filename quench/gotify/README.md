# Quenchworks gotify

Hardened [gotify](https://gotify.net/) push-notification server on a minimal,
nonroot, 0-CVE image pinned by digest. Single node; persists its SQLite DB and
uploaded images/plugins to a PVC.

## Install

```bash
helm install my-gotify oci://ghcr.io/quenchworks/charts/gotify
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-gotify-gotify 8080:80
# http://127.0.0.1:8080  (default login admin / admin)
```

> The default admin login is `admin` / `admin`. **Change the password after first
> login**, or set `GOTIFY_DEFAULTUSER_NAME` / `GOTIFY_DEFAULTUSER_PASS` via
> `extraEnvVars` (better: a Secret referenced by `extraEnvVarsSecret`) before the
> first boot.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gotify \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/gotify \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/gotify` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (SQLite); do not scale out. |
| `containerPort` | `8080` | Port gotify binds (nonroot). Wired to `GOTIFY_SERVER_PORT`. |
| `service.port` | `80` | Service port, forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC mounted at `/app/data` (DB + images + plugins). |
| `persistence.size` | `1Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Set a deterministic admin password:

```yaml
extraEnvVars:
  - name: GOTIFY_DEFAULTUSER_NAME
    value: admin
  - name: GOTIFY_DEFAULTUSER_PASS
    value: change-me
```

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/app/data` PVC is writable. Gotify serves `/health` (returns
`{"health":"green",...}`), used for both liveness and readiness probes.

## Notes

Single node only: gotify stores everything in a local SQLite database plus a
directory of uploaded images and plugins, so it cannot be horizontally scaled.
For HA you would need an external database backend, tracked as a follow-up.

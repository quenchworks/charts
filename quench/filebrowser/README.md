# Quenchworks filebrowser

Hardened [File Browser](https://filebrowser.org/) web file manager on a minimal,
nonroot, 0-CVE image pinned by digest. Single node; persists its SQLite DB and
the served files directory to a PVC.

## Install

```bash
helm install my-filebrowser oci://ghcr.io/quenchworks/charts/filebrowser
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-filebrowser-filebrowser 8080:80
# http://127.0.0.1:8080
```

> On first boot File Browser creates an `admin` user with a **randomly generated
> password**, printed to the pod logs. Read it and **change it after first
> login**:
>
> ```bash
> kubectl logs my-filebrowser-filebrowser-0 | grep -i password
> ```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/filebrowser \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/filebrowser \
  --owner quenchworks
```

## Values

| Key                           | Default                                  | Notes                                                                                     |
| ----------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/filebrowser` |                                                                                           |
| `image.digest`                | (CI-written)                             | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                      | Stateful single node (SQLite); do not scale out.                                          |
| `containerPort`               | `8080`                                   | Port File Browser binds (nonroot). Wired to `FB_PORT`.                                    |
| `service.port`                | `80`                                     | Service port, forwards to the container's `http` port.                                    |
| `persistence.enabled`         | `true`                                   | 1Gi PVC; DB at `/database`, served files at `/srv`.                                       |
| `persistence.size`            | `1Gi`                                    |                                                                                           |
| `persistence.existingClaim`   | `""`                                     | Bind an existing PVC instead of provisioning one.                                         |
| `serviceAccount.create`       | `true`                                   | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                                  | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                                   | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                                   | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                                  | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                     | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                     | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                                   | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                     | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                     | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Further configuration uses File Browser's `FB_*` environment variables via
`extraEnvVars` (or a Secret referenced by `extraEnvVarsSecret`):

```yaml
extraEnvVars:
  - name: FB_NOAUTH
    value: "false"
```

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the PVC-backed `/database` (SQLite DB) and `/srv` (served files)
paths are writable. File Browser serves `/health` (returns `{"status":"OK"}`),
used for both liveness and readiness probes.

## Notes

Single node only: File Browser stores everything in a local SQLite database plus
the served files directory, so it cannot be horizontally scaled.

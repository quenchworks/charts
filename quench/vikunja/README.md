# Quenchworks vikunja

Hardened [Vikunja](https://vikunja.io/) self-hosted to-do & project-management
app (Go single binary with an embedded frontend) on a minimal, nonroot, 0-CVE
image pinned by digest. Single node; persists its SQLite DB and uploaded
attachments to a PVC.

## Install

```bash
helm install my-vikunja oci://ghcr.io/quenchworks/charts/vikunja
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-vikunja-vikunja 3456:80
# http://127.0.0.1:3456  (register the first account through the UI)
```

> Set a fixed JWT secret before first boot, or the server generates a random one
> on every start and logs all users out on restart:
>
> ```yaml
> extraEnvVars:
>   - name: VIKUNJA_SERVICE_JWTSECRET
>     value: change-me   # better: reference a Secret via extraEnvVarsSecret
> ```
>
> Rotate the secret deliberately in production.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vikunja \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/vikunja` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (SQLite); do not scale out. |
| `containerPort` | `3456` | Port vikunja binds (nonroot). Wired to `VIKUNJA_SERVICE_INTERFACE`. |
| `service.port` | `80` | Service port, forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC; DB at `/db`, uploaded files at `/files` (subpaths of one claim). |
| `persistence.size` | `1Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/db` and `/files` PVC subpaths are writable. Vikunja serves
`/api/v1/info` (returns 200 JSON once the server and DB are up), used for both
liveness and readiness probes.

## Notes

Single node only: vikunja stores everything in a local SQLite database plus a
directory of uploaded attachments, so it cannot be horizontally scaled. For HA
you would need an external database backend (PostgreSQL/MySQL), tracked as a
follow-up.

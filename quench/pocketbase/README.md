# Quenchworks pocketbase

Hardened [PocketBase](https://pocketbase.io/) — an open-source backend in a single
Go binary (SQLite DB, auth, file storage, realtime REST API and admin UI) — on a
minimal, nonroot, 0-CVE image pinned by digest. Single node; persists its SQLite
DB and uploaded files to a PVC.

## Install

```bash
helm install my-pocketbase oci://ghcr.io/quenchworks/charts/pocketbase
```

Then port-forward and open the admin dashboard:

```bash
kubectl port-forward svc/my-pocketbase-pocketbase 8090:80
# http://127.0.0.1:8090/_/   (create the initial superuser on first visit)
```

Create the first superuser non-interactively instead:

```bash
kubectl exec statefulset/my-pocketbase-pocketbase -- \
  pocketbase superuser upsert admin@example.com <password> --dir /pb_data
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pocketbase \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/pocketbase` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (SQLite); do not scale out. |
| `containerPort` | `8080` | Port PocketBase binds (baked into the image entrypoint, nonroot). |
| `service.port` | `80` | Service port, forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC mounted at `/pb_data` (DB + files + migrations + backups). |
| `persistence.size` | `1Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/pb_data` PVC and an in-memory `/tmp` (upload scratch) are
writable. PocketBase serves `GET /api/health` (returns
`{"code":200,"message":"API is healthy.",...}`), used for both liveness and
readiness probes.

## Notes

Single node only: PocketBase stores everything in a local SQLite database plus a
directory of uploaded files, so it cannot be horizontally scaled. The image's
entrypoint is baked as `pocketbase serve --http 0.0.0.0:8080 --dir /pb_data`.

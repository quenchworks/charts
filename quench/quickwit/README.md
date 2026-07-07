# Quenchworks quickwit

Hardened [Quickwit](https://quickwit.io/) — a cloud-native search engine for logs
and traces (Rust), with the bundled admin UI — on a minimal, nonroot, 0-CVE image
pinned by digest. Single node (standalone); persists its index data and local split
cache to a PVC.

## Install

```bash
helm install my-quickwit oci://ghcr.io/quenchworks/charts/quickwit
```

Then port-forward and open the admin UI:

```bash
kubectl port-forward svc/my-quickwit-quickwit 7280:7280
# http://127.0.0.1:7280/ui
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/quickwit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/quickwit` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (local storage); do not scale out. |
| `containerPort` | `7280` | REST API + admin UI port (nonroot, binds 0.0.0.0). |
| `grpcPort` | `7281` | gRPC port (inter-node / clients). |
| `service.port` | `7280` | Service port for the REST/HTTP `http` port. |
| `service.grpcPort` | `7281` | Service port for the `grpc` port. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/quickwit/qwdata` (index data + split cache). |
| `persistence.size` | `8Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Point Quickwit at object storage + a shared metastore (for a distributed setup) via
`extraEnvVars`:

```yaml
extraEnvVars:
  - name: QW_METASTORE_URI
    value: s3://my-bucket/quickwit-metastore
  - name: QW_DEFAULT_INDEX_ROOT_URI
    value: s3://my-bucket/quickwit-indexes
```

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/quickwit/qwdata` PVC and an in-memory `/tmp` are writable. The
image ships a baked default config at `/quickwit/config/quickwit.yaml` (`QW_CONFIG`),
so a single node boots with no extra configuration. Quickwit serves `/health/livez`
(liveness) and `/health/readyz` (readiness), used for the probes.

## Notes

Single node only: this chart runs `quickwit run` (standalone) with local file
storage, so index data lives on the node's PVC and cannot be horizontally scaled.
For HA / a distributed cluster, front it with object storage (S3/GCS/Azure) and a
shared metastore.

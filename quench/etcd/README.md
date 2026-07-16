# Quenchworks etcd

Hardened etcd on a minimal, nonroot, 0-CVE image pinned by digest. Single-node
coordination store; the image is configured entirely through `ETCD_*` env vars.

## Install

```bash
helm install my-etcd oci://ghcr.io/quenchworks/charts/etcd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/etcd \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/etcd \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/etcd` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node for now. |
| `persistence.enabled` | `true` | 8Gi PVC at `/data`. |
| `service.clientPort` | `2379` | |
| `service.peerPort` | `2380` | |
| `metrics.serviceMonitor.enabled` | `false` | etcd serves `/metrics` natively on the client port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Peer traffic allowed between members; client ingress from the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/data` volume is writable.

## Notes

Single node for now. A multi-node clustered topology (static peer discovery over
the headless service) and etcd RBAC auth / mTLS are tracked as follow-ups. Metrics
need no exporter: etcd exposes Prometheus metrics on the client port at `/metrics`.

# Quenchworks Pyroscope

Hardened [Grafana Pyroscope](https://grafana.com/oss/pyroscope/) continuous-profiling
database on a minimal, nonroot, 0-CVE image pinned by digest. Runs monolithic
(single-binary, `-target=all`); persists its profiling blocks and metastore raft
state to a PVC.

## Install

```bash
helm install my-pyroscope oci://ghcr.io/quenchworks/charts/pyroscope
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-pyroscope-pyroscope 4040:4040
# http://127.0.0.1:4040
```

Point your profiling agents / SDKs at the service URL. With multitenancy
disabled (the default), profiles land under the anonymous tenant.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pyroscope \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/pyroscope \
  --owner quenchworks
```

## Values

| Key                           | Default                                | Notes                                                                                     |
| ----------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- | ----------- |
| `image.repository`            | `ghcr.io/quenchworks/images/pyroscope` |                                                                                           |
| `image.digest`                | (CI-written)                           | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                    | Monolithic single node; do not scale out.                                                 |
| `containerPort`               | `4040`                                 | Port Pyroscope binds (nonroot). Probes hit `/ready` on it.                                |
| `service.port`                | `4040`                                 | Service port, forwards to the container's `http` port.                                    |
| `persistence.enabled`         | `true`                                 | 8Gi PVC for the profiling DB + metastore raft state.                                      |
| `persistence.size`            | `8Gi`                                  |                                                                                           |
| `persistence.mountPath`       | `/data`                                | Pinned to the `-pyroscopedb.data-path` flag.                                              |
| `persistence.existingClaim`   | `""`                                   | Bind an existing PVC instead of provisioning one.                                         |
| `args`                        | `[]`                                   | Extra flags appended after the built-in `-pyroscopedb.data-path`.                         |
| `serviceAccount.create`       | `true`                                 | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                                | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                                 | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                                 | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                                | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                   | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                   | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                                 | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                   | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                   | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/data` PVC and an emptyDir at `/tmp` are writable. Pyroscope
serves `/ready` (200 once metastore + ingester are up), used for the liveness,
readiness and a generous startup probe (~60s cold-start allowance).

## Notes

Single node only: this chart runs Pyroscope monolithic with local block storage
and an embedded metastore raft, so it cannot be horizontally scaled. For a
distributed / HA deployment you would run the microservices targets against
object storage (S3/GCS/Azure), tracked as a follow-up.

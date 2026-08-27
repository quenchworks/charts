# Quenchworks nsq

Hardened [NSQ](https://nsq.io/) realtime distributed messaging on a minimal,
nonroot, 0-CVE image pinned by digest. Ships a single `nsqd` node that persists
its topic/channel disk-queue to a PVC.

## Install

```bash
helm install my-nsq oci://ghcr.io/quenchworks/charts/nsq
```

Then port-forward the HTTP API:

```bash
kubectl port-forward svc/my-nsq-nsq 4151:4151
curl http://127.0.0.1:4151/ping                       # -> 200 OK
curl -d 'hello' 'http://127.0.0.1:4151/pub?topic=test' # publish a message
```

Producers/consumers connect to `nsqd` over TCP on port `4150`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nsq \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/nsq \
  --owner quenchworks
```

## Values

| Key                           | Default                          | Notes                                                                                     |
| ----------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------- | ----------- |
| `image.repository`            | `ghcr.io/quenchworks/images/nsq` |                                                                                           |
| `image.digest`                | (CI-written)                     | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                              | Stateful single node (disk-queue); do not scale out.                                      |
| `tcpPort`                     | `4150`                           | nsqd TCP port (producers/consumers).                                                      |
| `httpPort`                    | `4151`                           | nsqd HTTP API port (`/ping`, `/pub`, `/stats`).                                           |
| `service.tcpPort`             | `4150`                           | Service port forwarding to the container's `tcp` port.                                    |
| `service.httpPort`            | `4151`                           | Service port forwarding to the container's `http` port.                                   |
| `persistence.enabled`         | `true`                           | 8Gi PVC mounted at `/data` (nsqd `--data-path`).                                          |
| `persistence.size`            | `8Gi`                            |                                                                                           |
| `persistence.existingClaim`   | `""`                             | Bind an existing PVC instead of provisioning one.                                         |
| `serviceAccount.create`       | `true`                           | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                          | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                           | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                           | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                          | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                             | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                             | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                           | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                             | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                             | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/data` PVC is writable. nsqd serves `GET /ping` (returns
`200 OK`), used for both liveness and readiness probes. The default entrypoint
is `nsqd`, launched with `--data-path=/data` and `--broadcast-address=<pod>`.

## Notes

Single node only: this chart runs one standalone `nsqd` that stores its
topic/channel disk-queue on a local PVC, so it cannot be horizontally scaled.
`nsqlookupd` discovery, additional `nsqd` nodes, and the `nsqadmin` web UI are
out of scope and tracked as a follow-up.

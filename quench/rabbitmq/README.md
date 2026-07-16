# Quenchworks RabbitMQ

Hardened RabbitMQ on a minimal, nonroot, 0-CVE image pinned by digest. Built from
source on Wolfi's Erlang runtime. On first boot the broker seeds a default user from
the chart's Secret and drops the stock guest account; the chart pins the image by its
signed digest.

## Install

```bash
helm install my-rabbitmq oci://ghcr.io/quenchworks/charts/rabbitmq
```

Set your own user and password:

```bash
helm install my-rabbitmq oci://ghcr.io/quenchworks/charts/rabbitmq \
  --set auth.username='app' --set auth.password='change-me'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rabbitmq \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/rabbitmq \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/rabbitmq` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.username` | `user` | Default broker user created on first boot. |
| `auth.password` | `""` | Generated into a Secret if empty. |
| `auth.erlangCookie` | `""` | Generated if empty. Pins node identity across restarts. |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/rabbitmq`. |
| `service.port` | `5672` | AMQP. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/rabbitmq` and `/tmp` are writable.

## Notes

Single node for now. Clustering (quorum queues across replicas), the management plugin,
TLS listeners, and a metrics exporter are tracked as follow-ups. Depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

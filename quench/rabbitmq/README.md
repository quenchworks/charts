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

## Standalone vs HA

The default install is a 3-node cluster with quorum queues, so queues are HA out
of the box. For dev/test or a small footprint, run a single node instead:

```bash
# Standalone: 1 node, no clustering or failover, smallest footprint
helm install my-rabbitmq oci://ghcr.io/quenchworks/charts/rabbitmq \
  --set replicaCount=1

# HA (default): 3-node cluster with quorum queues (Raft-replicated)
helm install my-rabbitmq oci://ghcr.io/quenchworks/charts/rabbitmq
```

Standalone is one pod, and a classic queue on it does not survive its loss. HA
forms one cluster over the headless Service (Kubernetes peer discovery v2, no
RBAC): the ordinal-0 pod seeds and the rest join, all in parallel with no
split-brain race. Queues default to the quorum type, so their Raft log replicates
across nodes and keeps serving while a majority is up. `pause_minority` stops the
losing side of a network split so writes can't diverge, and a PodDisruptionBudget
(`minAvailable: 2`) keeps a voluntary drain from dropping below the queue
majority. Keep the node count odd (3 tolerates 1 loss, 5 tolerates 2). Losing the
majority is a split-brain boundary that a human resolves, not auto-recovery.

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
| `replicaCount` | `3` | Cluster size. Use an odd number for quorum. `1` = single node, no HA. |
| `clustering.quorumQueuesDefault` | `true` | Default queues to the quorum (Raft-replicated) type. |
| `clustering.partitionHandling` | `pause_minority` | Network-split policy. `autoheal`/`ignore` also available. |
| `management.enabled` | `true` | Management HTTP API + web UI on 15672. |
| `primary.persistence.enabled` | `true` | 8Gi PVC at `/var/lib/rabbitmq`. |
| `service.port` | `5672` | AMQP. |
| `service.managementPort` | `15672` | Management API/UI. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/var/lib/rabbitmq` and `/tmp` are writable.

## Notes

TLS listeners and a metrics exporter are tracked as follow-ups. Depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

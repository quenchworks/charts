# Quenchworks NATS

Hardened NATS server on a minimal, nonroot, 0-CVE image pinned by digest. Runs a
single combined server with JetStream persistence on by default; the chart owns the
server command so flags are deterministic, and the image is pinned by its signed
digest.

## Install

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats
```

Core NATS only (no JetStream, no persistence):

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats \
  --set nats.jetstream.enabled=false --set persistence.enabled=false
```

Pass any other server flag without changing the chart:

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats \
  --set 'nats.extraArgs[0]=--max_payload' \
  --set 'nats.extraArgs[1]=8MB'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nats \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/nats` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `nats.jetstream.enabled` | `true` | Enable JetStream; store lives on the data volume. |
| `nats.extraArgs` | `[]` | Any extra `nats-server` flags. |
| `replicaCount` | `1` | Single combined server; clustering is a follow-up. |
| `persistence.enabled` | `true` | 8Gi PVC at `/data` for the JetStream store. |
| `service.clientPort` | `4222` | Client connections. |
| `service.monitorPort` | `8222` | HTTP monitoring (`/healthz`, `/varz`); probes use it. |
| `service.clusterPort` | `6222` | Route connections between servers (headless). |
| `networkPolicy.enabled` | `true` | Restricts client ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`, scheduling
(`affinity`/`nodeSelector`/`tolerations`/`topologySpreadConstraints`), `initContainers`,
`sidecars`, `extraVolumes`/`extraVolumeMounts`, `lifecycleHooks`, configurable probes,
and overridable security contexts.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/data` and `/tmp` are writable.

## Notes

Single-node, no authentication, reachable only inside the cluster (the NetworkPolicy
restricts client ingress to the release namespace). Multi-node clustering, auth/TLS,
and a first-class metrics path (NATS has no native Prometheus endpoint — add the
prometheus-nats-exporter via the `sidecars` knob) are tracked follow-ups. Depends on
the `quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

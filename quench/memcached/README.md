# Quenchworks memcached

Hardened memcached on a minimal, nonroot, 0-CVE image pinned by digest. memcached is
a stateless in-memory cache, so this chart runs a **Deployment** (no persistence, no
stable identity) that can scale horizontally behind the service. The chart owns the
server command so flags are deterministic, and the image is pinned by its signed digest.

## Install

```bash
helm install my-cache oci://ghcr.io/quenchworks/charts/memcached
```

Tune the cache:

```bash
helm install my-cache oci://ghcr.io/quenchworks/charts/memcached \
  --set memcached.memoryLimitMB=512 --set memcached.maxConnections=4096
```

Scale out automatically on CPU:

```bash
helm install my-cache oci://ghcr.io/quenchworks/charts/memcached \
  --set autoscaling.enabled=true --set autoscaling.maxReplicas=8
```

Pass any other server flag without changing the chart:

```bash
helm install my-cache oci://ghcr.io/quenchworks/charts/memcached \
  --set 'memcached.extraArgs[0]=--enable-largepages'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/memcached \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/memcached \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/memcached` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Ignored when `autoscaling.enabled`. |
| `memcached.memoryLimitMB` | `64` | `-m`: max item memory (MB). |
| `memcached.maxConnections` | `1024` | `-c`: max simultaneous connections. |
| `memcached.threads` | `4` | `-t`: worker threads. |
| `memcached.extraArgs` | `[]` | Any extra `memcached` flags. |
| `service.port` | `11211` | Cache port. |
| `autoscaling.enabled` | `false` | HPA on CPU when true. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`, scheduling
(`affinity`/`nodeSelector`/`tolerations`/`topologySpreadConstraints`), `initContainers`,
`sidecars`, `extraVolumes`/`extraVolumeMounts`, `lifecycleHooks`, configurable probes,
and overridable security contexts.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Only `/tmp` is writable. Reachable only inside the cluster (the NetworkPolicy restricts
ingress to the release namespace).

## Notes

No authentication (memcached has none in the core protocol; rely on the NetworkPolicy
and network boundaries). TLS and SASL are tracked follow-ups. Depends on the
`quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

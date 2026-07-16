# Quenchworks ZooKeeper

Hardened Apache ZooKeeper on a minimal, nonroot, 0-CVE image pinned by digest.
Packaged on the same hardened `openjdk-21-jre` base as the other JVM charts. The
image writes `zoo.cfg` from `ZOO_*` env on boot; the chart pins the image by its
signed digest and runs a single standalone server.

## Install

```bash
helm install zk oci://ghcr.io/quenchworks/charts/zookeeper
```

Tune it:

```bash
helm install zk oci://ghcr.io/quenchworks/charts/zookeeper \
  --set config.maxClientCnxns=200 --set persistence.size=20Gi
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/zookeeper \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/zookeeper \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/zookeeper` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Standalone; ensemble is a follow-up. |
| `config.tickTime` | `2000` | Base time unit (ms). |
| `config.initLimit` | `10` | Follower init ticks. |
| `config.syncLimit` | `5` | Follower sync ticks. |
| `config.maxClientCnxns` | `60` | Per-IP client connection limit. |
| `persistence.enabled` | `true` | 8Gi PVC at `/data`. |
| `service.clientPort` | `2181` | Client connections. |
| `service.peerPort` | `2888` | Ensemble peer (headless). |
| `service.electionPort` | `3888` | Leader election (headless). |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only `/data`, `/conf`, and the log dir are writable. The readiness probe
uses the `ruok` four-letter word over the client port; the 4lw allowlist is
restricted to read-only commands. The Jetty-backed AdminServer is absent from the
image (removed to clear the jetty 9.4 CVEs), so no HTTP admin port is exposed.

## Notes

Single standalone server. Multi-node ensembles (`ZOO_SERVERS` + per-pod `myid`) and
a Prometheus metrics provider are tracked follow-ups. Depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

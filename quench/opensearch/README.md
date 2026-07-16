# Quenchworks OpenSearch

Hardened [OpenSearch](https://opensearch.org/) on a minimal, nonroot, 0-CVE image
pinned by digest. Packaged on the shared `openjdk-21-jre` base (the bundled JDK is
stripped so the JRE stays the scanned CVE surface). Single-node by default; the image
writes `opensearch.yml` from `OPENSEARCH_*` env.

## Install

```bash
helm install os oci://ghcr.io/quenchworks/charts/opensearch
```

Then query it:

```bash
kubectl run q --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://os-opensearch:9200/_cluster/health
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/opensearch \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/opensearch \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/opensearch` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; multi-node cluster is a follow-up. |
| `config.clusterName` | `quench-opensearch` | |
| `config.discoveryType` | `single-node` | Dev mode; relaxes bootstrap checks. |
| `config.securityDisabled` | `true` | Security plugin off (internal use behind the NetworkPolicy). |
| `config.heapSize` | `512m` | JVM heap (`-Xms`/`-Xmx`). |
| `persistence.enabled` | `true` | 16Gi PVC at `/data` (config + logs live there too). |
| `service.httpPort` | `9200` | REST API. |
| `service.transportPort` | `9300` | Node transport (headless). |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Config, data, and logs live on the writable `/data` volume. The security
plugin is disabled by default for an internal deployment; enable it and configure
TLS for anything exposed beyond the cluster boundary.

## Notes

Single node. Multi-node clusters and the security plugin (TLS + auth) are tracked
follow-ups. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

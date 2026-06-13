# Quenchworks Elasticsearch

> **LICENSE -- NOT OPEN SOURCE.** Elasticsearch's default distribution is dual
> **SSPL-1.0 / Elastic License 2.0** -- **NEITHER is OSI-approved open source.**
> Do not represent it as open source.
> **CLEAN ALTERNATIVE: [OpenSearch](../opensearch) (Apache-2.0) is the truly-open
> drop-in fork of Elasticsearch -- prefer it for new deployments.** This chart exists
> for parity/migration only. CAUTION TIER.

Hardened [Elasticsearch](https://github.com/elastic/elasticsearch) on a minimal,
nonroot, 0-CVE image pinned by digest. Runs on the hardened Wolfi-packaged OpenJDK 21
(the bundled JDK is dropped so the Wolfi JDK stays the scanned CVE surface). Single-node
by default; the image writes `elasticsearch.yml` from `ES_*` env.

## Install

```bash
helm install es oci://ghcr.io/quenchworks/charts/elasticsearch
```

Then query it:

```bash
kubectl run q --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://es-elasticsearch:9200/_cluster/health
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/elasticsearch \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/elasticsearch` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; multi-node cluster is a follow-up. |
| `config.clusterName` | `quench-elasticsearch` | |
| `config.discoveryType` | `single-node` | Relaxes production bootstrap checks. |
| `config.securityDisabled` | `true` | `xpack.security` off (internal use behind the NetworkPolicy). |
| `config.heapSize` | `512m` | JVM heap (`-Xms`/`-Xmx`). |
| `config.extraConfig` | `""` | Raw YAML appended to `elasticsearch.yml` (`ES_CONFIG_EXTRA`). |
| `persistence.enabled` | `true` | 16Gi PVC at `/data`. |
| `service.httpPort` | `9200` | REST API. |
| `service.transportPort` | `9300` | Node transport (headless). |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Config (`/conf`), logs (`/var/log/elasticsearch`) and `/tmp` are writable
`emptyDir` mounts; data lives on the persistent `/data` volume (with `ES_TMPDIR` at
`/data/tmp`). `/tmp` MUST be writable: the ES 9.x entitlement agent attaches over a
Unix socket at `/tmp/.java_pid<pid>` and the node will not boot otherwise.

`xpack.security` is disabled by default for an internal deployment; enable it
(`config.securityDisabled=false`) and configure TLS for anything exposed beyond the
cluster boundary.

## Notes

Single node. Multi-node clusters and security (TLS + auth) are tracked follow-ups.
Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

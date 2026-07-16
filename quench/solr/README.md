# Quenchworks Solr

Hardened [Apache Solr](https://solr.apache.org/) on a minimal, nonroot, 0-CVE image
pinned by digest. Packaged on the shared `openjdk-21-jre` base (the JRE is the scanned
CVE surface). Single-node standalone by default; SolrCloud (`config.zkHost`) is a
follow-up. The entrypoint relocates `SOLR_HOME`/logs/pid/tmp onto a single writable
mount at `/var/solr` so it runs on a read-only rootfs.

## Install

```bash
helm install solr oci://ghcr.io/quenchworks/charts/solr
```

Then create a core, index a doc, and query it:

```bash
kubectl run q --rm -it --image=curlimages/curl --restart=Never -- sh -c '
  curl "http://solr-solr:8983/solr/admin/cores?action=CREATE&name=mycore&configSet=_default"
  curl -XPOST "http://solr-solr:8983/solr/mycore/update?commit=true" \
    -H "Content-Type: application/json" -d "[{\"id\":\"1\",\"title_s\":\"quench\"}]"
  curl "http://solr-solr:8983/solr/mycore/select?q=id:1"
'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/solr \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/solr \
  --owner quenchworks
```

## Security

Apache Solr ships **no authentication** by default. This chart relies on the
**NetworkPolicy** (`networkPolicy.enabled=true`, `allowExternal=false`) as its trust
boundary: ingress on port 8983 is restricted to in-cluster pods. There is no Secret.
Do not expose Solr externally without an authenticating proxy in front of it.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/solr` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; SolrCloud is a follow-up. |
| `config.heapSize` | `512m` | JVM heap (`SOLR_HEAP`, `-Xms`/`-Xmx`). |
| `config.core` | `""` | Optional core precreated on first boot from `_default`. |
| `config.zkHost` | `""` | Set a ZooKeeper connect string to enable SolrCloud (`SOLR_ZK_HOST`). |
| `config.optsExtra` | `""` | Extra JVM opts appended to `SOLR_OPTS` (`SOLR_OPTS_EXTRA`). |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/var/solr` (data + logs + pid + tmp). |
| `persistence.size` | `8Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 250m / mem 768Mi` | |
| `resources.limits` | `cpu 2 / mem 1536Mi` | |
| `service.type` | `ClusterIP` | |
| `service.httpPort` | `8983` | The only Solr port. |
| `networkPolicy.enabled` | `true` | The security boundary (Solr has no auth). |
| `networkPolicy.allowExternal` | `false` | Restrict ingress to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

## Storage layout

The read-only rootfs forces everything writable under one mount. The chart mounts the
`data` volume at `/var/solr`, which covers:

- `SOLR_HOME=/var/solr/data` (cores + configsets; seeded from the dist `_default` on first boot)
- `SOLR_LOGS_DIR=/var/solr/logs`
- `SOLR_PID_DIR=/var/solr`
- `TMPDIR=/var/solr/tmp`

## Health probe

Readiness and liveness use `httpGet /solr/admin/info/health` on 8983 (unauthenticated,
returns status OK). The initial delay is generous (~20-40s) to cover JVM boot.

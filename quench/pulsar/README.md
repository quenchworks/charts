# Quenchworks Pulsar

Hardened [Apache Pulsar](https://pulsar.apache.org/) on a minimal, nonroot, 0-CVE image
pinned by digest. Packaged on the shared `openjdk-21-jre` base (the JRE plus the bundled
Pulsar jars are the scanned CVE surface). Single-node **standalone**: the broker, an
in-process BookKeeper bookie, and the embedded RocksDB metadata store run in ONE JVM --
no external ZooKeeper/bookie. A multi-node cluster is a follow-up.

The lean `-bin` distribution is shipped: Pulsar IO connectors and tiered-storage
offloaders are excluded, and the functions worker + BookKeeper stream storage are
disabled by default (re-enable via `config.functionsWorker` / `config.streamStorage`).

The entrypoint relocates ALL writable state (BookKeeper journal+ledgers, embedded
RocksDB metadata, logs, the seeded conf, the JVM tmpdir) onto a single writable mount at
`/pulsar` so it runs on a read-only rootfs.

## Install

```bash
helm install pulsar oci://ghcr.io/quenchworks/charts/pulsar
```

Then produce and consume a message:

```bash
kubectl exec pulsar-pulsar-0 -- /opt/pulsar/bin/pulsar-client produce \
  -m 'hello-quench' -n 1 persistent://public/default/demo
kubectl exec pulsar-pulsar-0 -- /opt/pulsar/bin/pulsar-client consume \
  -s sub -n 1 -p Earliest persistent://public/default/demo
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pulsar \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/pulsar \
  --owner quenchworks
```

## Security

Apache Pulsar ships **no authentication** by default. This chart relies on the
**NetworkPolicy** (`networkPolicy.enabled=true`, `allowExternal=false`) as its trust
boundary: ingress on 6650 (binary) and 8080 (HTTP) is restricted to in-cluster pods.
There is no Secret. Do not expose Pulsar externally without an authenticating proxy.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/pulsar` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node; multi-node cluster is a follow-up. |
| `config.mem` | `-Xms512m -Xmx512m -XX:MaxDirectMemorySize=512m` | JVM heap + direct memory (`PULSAR_MEM`). |
| `config.advertisedAddress` | `""` | `PULSAR_ADVERTISED_ADDRESS`; empty = broker advertises its own hostname. |
| `config.functionsWorker` | `false` | Re-enable the functions worker (`PULSAR_FUNCTIONS_WORKER=1`). |
| `config.streamStorage` | `false` | Re-enable BookKeeper stream storage (`PULSAR_STREAM_STORAGE=1`). |
| `config.extraOpts` | `""` | Extra JVM opts (`PULSAR_EXTRA_OPTS`). |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/pulsar` (data + logs + conf + tmp). |
| `persistence.size` | `8Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 500m / mem 1Gi` | Standalone is memory-hungry. |
| `resources.limits` | `cpu 2 / mem 3Gi` | Raise if the pod is OOMKilled. |
| `service.type` | `ClusterIP` | |
| `service.pulsarPort` | `6650` | Binary protocol (`pulsar://`) for clients. |
| `service.httpPort` | `8080` | HTTP admin / REST API. |
| `networkPolicy.enabled` | `true` | The security boundary (Pulsar has no auth). |
| `networkPolicy.allowExternal` | `false` | Restrict ingress to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

## Storage layout

The read-only rootfs forces everything writable under one mount. The chart mounts the
`data` volume at `/pulsar`, which covers:

- `PULSAR_DATA_DIR=/pulsar/data` (BookKeeper journal+ledgers + embedded RocksDB metadata)
- `PULSAR_LOG_DIR=/pulsar/logs`
- `PULSAR_CONF_DIR=/pulsar/conf` (seeded from the dist on first boot)
- `PULSAR_TMP_DIR=/pulsar/tmp` (`java.io.tmpdir` + `ROCKSDB_SHAREDLIB_DIR`)

**The `/pulsar` mount must allow `exec`.** RocksDB and the bookie extract a native `.so`
to the JVM tmpdir (under `/pulsar/tmp`) and mmap it; a `noexec` mount fails with
"failed to map segment". Standard PVC/emptyDir is exec-capable -- just do not add a
`noexec` mount option or a securityContext that blocks it.

## Health probe

Readiness and liveness use `httpGet /admin/v2/brokers/health` on 8080 (unauthenticated,
returns `ok`). Initial delays are generous (~40-60s) because standalone boots slowly.

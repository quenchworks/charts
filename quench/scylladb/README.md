# Quenchworks ScyllaDB

Hardened [ScyllaDB Open Source](https://github.com/scylladb/scylladb) — a
high-throughput, low-latency wide-column store that is Cassandra-compatible (CQL)
— on a minimal, nonroot, 0-CVE image, cosign-signed (keyless / Sigstore) and
pinned by digest. The image ships ScyllaDB's official relocatable binary on a
hardened Wolfi base; its entrypoint seeds `scylla.yaml` from `SCYLLA_*` env on
boot and runs Scylla in container/developer mode so it works in an unprivileged,
read-only-rootfs pod.

> **License:** ScyllaDB Open Source is **AGPL-3.0-only** (OSI-approved). The image
> redistributes the upstream binary unmodified and carries its NOTICE/licenses.

## Install

```bash
helm install sc oci://ghcr.io/quenchworks/charts/scylladb
```

Tune it:

```bash
helm install sc oci://ghcr.io/quenchworks/charts/scylladb \
  --set config.smp=2 --set config.memory=4G \
  --set resources.requests.memory=4Gi --set resources.limits.memory=6Gi \
  --set persistence.size=50Gi
```

> **Memory is a hard cap.** `config.memory` (`SCYLLA_MEMORY` → `--memory`) bounds the
> Seastar allocator. Seastar's available-memory probe is conservative inside a cgroup,
> so keep `config.memory` well under `resources.requests.memory` (the default is
> `512M` under a `1Gi` request / `2Gi` limit). If you raise `config.memory`, raise the
> request and limit together with extra headroom — otherwise Scylla either fails its
> startup memory check or is OOMKilled.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/scylladb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/scylladb \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/scylladb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node; keep at 1 (multi-node is a follow-up). |
| `config.clusterName` | `Quench Cluster` | Must match across all nodes in a ring. |
| `config.smp` | `1` | CPU shares Scylla pins (`SCYLLA_SMP` → `--smp`). |
| `config.memory` | `512M` | Hard memory cap (`SCYLLA_MEMORY` → `--memory`). Keep well under `resources.requests.memory`. |
| `config.developerMode` | `true` | Relaxes AIO/fs/clocksource checks for containers. |
| `config.reactorBackend` | `epoll` | `epoll`, `linux-aio`, or `io_uring`; avoids io_uring/AIO when the kernel/seccomp blocks it. |
| `config.overprovisioned` | `true` | Yields CPU in shared environments. |
| `config.seedCount` | `1` | Stable seed pods for multi-node, clamped to `replicaCount`. |
| `config.yamlExtra` | `""` | Raw `scylla.yaml` appended verbatim. |
| `auth.enabled` | `false` | Toggle `PasswordAuthenticator` + `CassandraAuthorizer`. |
| `auth.authenticator` | `PasswordAuthenticator` | Authenticator when `auth.enabled`. |
| `auth.authorizer` | `CassandraAuthorizer` | Authorizer when `auth.enabled`. |
| `persistence.enabled` | `true` | 16Gi PVC per pod at `/var/lib/scylla`. |
| `persistence.size` | `16Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 500m / mem 1Gi` | |
| `resources.limits` | `cpu 2 / mem 2Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.cqlPort` | `9042` | CQL client port (ClusterIP + headless). |
| `service.apiPort` | `10000` | REST API (health/admin); ClusterIP, in-cluster only. |
| `service.internodePort` | `7000` | Gossip/storage (headless only). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to internode + REST (own pods) + CQL (clients). |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow CQL ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy); extra server
args pass through `command`/`args`.

## Architecture

Scylla runs as a **StatefulSet** so each node keeps a stable network identity and
its own persistent volume. Data, commitlog, and hints live on the PVC at
`/var/lib/scylla`; `/etc/scylla` is a writable `emptyDir` seeded from `SCYLLA_*`
env on first boot. Both are exec-capable because the bundled libreloc loader
mmaps from them. Everything else runs nonroot (uid 1001) on a read-only root
filesystem with all capabilities dropped.

Three ports are exposed: **CQL (9042)** for clients over both the ClusterIP and
the headless service, the **REST API (10000)** on the ClusterIP for in-cluster
health/admin only, and **internode gossip/storage (7000)** on the headless
service only. Readiness gates on the unauthenticated REST API
(`GET /storage_service/scylla_release_version` on 10000), so a pod takes traffic
only once the storage service is up. Prometheus metrics (9180) and the Alternator
DynamoDB API (8000) are not exposed by default.

The default topology is **single standalone node** (`replicaCount: 1`,
`seeds = self`). Multi-node rings via `replicaCount > 1` wire the first
`config.seedCount` pods as `SCYLLA_SEEDS` over the headless service; this path is
a tracked follow-up and is not yet validated at scale — keep `replicaCount` at 1
unless you are testing it.

## Configuration examples

Connect with a throwaway upstream client pod (the runtime image ships no
in-image `cqlsh`):

```bash
kubectl run cqlclient --rm -it --restart=Never --image=scylladb/scylla:6.2 -- \
  cqlsh sc-scylladb 9042
```

```sql
CREATE KEYSPACE IF NOT EXISTS demo WITH replication =
  {'class':'SimpleStrategy','replication_factor':1};
CREATE TABLE IF NOT EXISTS demo.t(id int PRIMARY KEY, v text);
INSERT INTO demo.t(id, v) VALUES (1, 'quench');
SELECT v FROM demo.t WHERE id = 1;
```

Enable login auth. This sets `PasswordAuthenticator` + `CassandraAuthorizer`, and
Scylla bootstraps the default `cassandra` / `cassandra` superuser — rotate it
immediately with `ALTER ROLE cassandra WITH PASSWORD = '<new-strong-password>';`:

```yaml
auth:
  enabled: true
```

Larger node with more CPU shares and matching memory headroom:

```yaml
config:
  smp: 4
  memory: 8G
resources:
  requests: { cpu: "4", memory: 10Gi }
  limits: { cpu: "6", memory: 12Gi }
persistence:
  size: 100Gi
```

## Uninstall

```bash
helm uninstall sc
```

PVCs provisioned by the `volumeClaimTemplate` are retained by Kubernetes on
uninstall — delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=sc
```

## Notes

Single standalone node by default; a validated multi-node ring
(`SCYLLA_SEEDS` peer discovery over the headless service) and a metrics exporter
are tracked follow-ups. Auth is off by default — the deployment is internal and
the NetworkPolicy is the trust boundary; enable `auth.enabled` before exposing
CQL beyond the cluster. The chart depends on the `quench-common` library chart,
pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs
nonroot on a read-only root filesystem with all capabilities dropped, and the
image is pinned by digest.

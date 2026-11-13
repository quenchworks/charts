# Quenchworks redis-operator

The [Redis Operator](https://github.com/OT-CONTAINER-KIT/redis-operator) 0.27.0
from OT-CONTAINER-KIT on the QuenchWorks image (built from source, nonroot,
CVE-gated at build, pinned by digest, cosign-signed). It runs Redis from
Kubernetes resources: `Redis` (standalone), `RedisReplication` (a primary with
replicas), `RedisSentinel` (failover for a replication) and `RedisCluster`
(sharded), with TLS, ACLs, persistence and an optional redis_exporter sidecar.

The chart installs the four CRDs from the release tag, the operator Deployment
and upstream's RBAC.

## Install

```bash
helm install redis-operator oci://ghcr.io/quenchworks/charts/redis-operator -n redis-operator --create-namespace
```

Then a primary with one replica:

```yaml
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: RedisReplication
metadata: { name: cache }
spec:
  clusterSize: 2
  kubernetesConfig: { image: redis:8.2 }
  redisExporter:
    enabled: true
    image: ghcr.io/quenchworks/images/redis-exporter:1.97.0
  storage:
    volumeClaimTemplate:
      spec: { accessModes: [ReadWriteOnce], resources: { requests: { storage: 1Gi } } }
```

## Values

| Key | Default | Notes |
|---|---|---|
| `featureGates` | `GenerateConfigInInitContainer=true` | `--feature-gates`; `""` keeps upstream's defaults |
| `watchNamespaces` | `[]` | `WATCH_NAMESPACE`; empty watches every namespace |
| `extraArgs` | `[]` | more operator flags, e.g. `--max-concurrent-reconciles=5` or `--zap-log-level=debug` |
| `replicaCount` | `1` | leader election is always on; extra replicas are standbys |
| `rbac.create` | `true` | upstream's ClusterRole plus a leader-election Role |

## Notes

- This chart turns on the alpha `GenerateConfigInInitContainer` feature gate
  (upstream's default is off). The operator image then runs as the
  `init-config` init container (`/operator agent bootstrap`, image set through
  `INIT_CONTAINER_IMAGE` to this chart's pinned digest) and writes
  `redis.conf`, so the Redis pods can run any Redis image that has `sh` and
  `redis-cli`: the official `redis` image works. Without the gate, the operator
  expects the `quay.io/opstree/redis` images and their entrypoint.
- The QuenchWorks `redis` image has no shell, and the operator's probes and
  preStop hooks run `sh -ec ... redis-cli`, so it cannot be the Redis image here
  yet. The QuenchWorks `redis-exporter` image works as the exporter sidecar.
- Webhooks are off (`--enable-webhooks=false`); upstream ships them disabled by
  default too.
- Metrics are plain HTTP on 8080. `--metrics-secure` switches to HTTPS with token
  authentication, which also needs TokenReview and SubjectAccessReview rights the
  chart does not grant.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/` yourself before upgrading across operator releases.

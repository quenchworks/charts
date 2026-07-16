# Quenchworks Floci

Hardened [Floci](https://github.com/floci-io/floci), a self-hosted,
LocalStack-compatible local AWS emulator built on Quarkus, on a minimal,
nonroot, 0-CVE image pinned by digest and cosign-signed (keyless / Sigstore).

## Install

```sh
helm install floci oci://ghcr.io/quenchworks/charts/floci
```

Floci runs nonroot (uid 1001) on a read-only root filesystem. It is configured
entirely through environment variables; no config file is needed. Point any AWS
SDK or CLI at the Service endpoint on port `4566` (LocalStack-compatible):

```sh
kubectl port-forward svc/floci 4566:4566
curl http://127.0.0.1:4566/_floci/health
aws --endpoint-url http://127.0.0.1:4566 s3 mb s3://demo
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/floci \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/floci --owner quenchworks`.

## Values

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/floci` | |
| `image.tag` | `1.5.32` | Reference only; the pod pulls by digest. |
| `image.digest` | (CI-maintained) | Signed multi-arch index (hardened image). Pinned by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `replicaCount` | `1` | Keep at 1 with in-process storage. |
| `floci.mode` | `hardened` | `hardened` (nonroot) or `full` (root + host docker.sock). |
| `floci.full.acknowledgeRisk` | `false` | Must be `true` for `mode=full` or the chart refuses to render. |
| `floci.full.image.repository` | `ghcr.io/quenchworks/images/floci-full` | Only used when `mode=full`. |
| `floci.full.image.digest` | (pinned) | Signed multi-arch `floci-full` index. |
| `floci.port` | `4566` | Edge/API + health port. |
| `floci.defaultRegion` | `us-east-1` | `FLOCI_DEFAULT_REGION`. |
| `floci.defaultAccountId` | `"000000000000"` | `FLOCI_DEFAULT_ACCOUNT_ID`. |
| `floci.localstackParity` | `false` | `LOCALSTACK_PARITY`. |
| `floci.storage.mode` | `memory` | `FLOCI_STORAGE_MODE` (`memory`, `persistent`, `hybrid`, `wal`). |
| `floci.storage.path` | `/data` | `FLOCI_STORAGE_PERSISTENT_PATH` (PVC mount). |
| `persistence.enabled` | `false` | Mount a PVC at `floci.storage.path`. |
| `persistence.size` | `8Gi` | |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `resources.requests` | `cpu 250m / mem 512Mi` | |
| `resources.limits` | `cpu 1 / mem 1Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `4566` | |
| `autoscaling.enabled` | `false` | Keep off with in-process storage (each replica keeps its own state). |
| `extraEnvVars` | `[]` | Extra `FLOCI_*` env (e.g. per-service config). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress restricted to the namespace by default. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `false` | |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

Floci holds all in-process state in memory by default (`FLOCI_STORAGE_MODE=memory`),
so the chart deploys a stateless Deployment with no volume. State is lost on
restart, which is fine for ephemeral dev/test. Liveness and readiness both hit
`GET /_floci/health` on the edge port (`4566`); it returns HTTP 200 with JSON
`{"services":{...}}` once the in-process services are ready.

### Hardened scope: in-process services (55 of 65)

Floci emulates 65 AWS services. 55 of them run entirely inside the single
nonroot Java process with no external dependencies, and this chart supports all
55, including:

S3, DynamoDB, SQS, SNS, SES, IAM, STS, KMS, Secrets Manager, SSM Parameter
Store, API Gateway, Cognito, Kinesis, CloudFormation, Step Functions,
EventBridge (plus Pipes and Scheduler), CloudWatch, CloudTrail, Config, Route53,
CloudFront, Cloud Map, ACM, Glue, Athena, Data Firehose, ELBv2, Auto Scaling,
AWS Batch, WAF v2, AppConfig, AppSync, Bedrock Runtime, CodeDeploy,
CodePipeline, AWS Backup, and Transfer Family.

The other 10 services spin up real containers and require the host Docker socket
(`/var/run/docker.sock`) plus root: Lambda, RDS, ElastiCache, MSK, ECS, EKS,
OpenSearch, ECR, DocumentDB, Neptune. That is incompatible with this hardened
image (nonroot uid 1001, no Docker socket, read-only root filesystem), so they
are out of scope for this chart. Do not mount the Docker socket into the pod. If
you need the Docker-backed services, run Floci on a Docker host outside
Kubernetes or use full mode below.

LocalStack API parity is disabled (`LOCALSTACK_PARITY=false`); clients still
target Floci's own LocalStack-wire-compatible endpoint on port `4566` for the
in-process services above.

### Storage and persistence

To keep state across restarts on a single replica, enable the PVC and switch the
storage mode:

| `floci.storage.mode` | Behaviour |
|----------------------|-----------|
| `memory` | All state in RAM, lost on restart (default; no volume). |
| `persistent` | Flush every write to disk. |
| `hybrid` | Async flush (~5s) to disk. |
| `wal` | Write-ahead log for durability. |

Any mode other than `memory` requires `persistence.enabled: true`, since the
root filesystem is read-only and a writable volume must be mounted at
`floci.storage.path`. This is best-effort single-replica durability, not a
scale-out mechanism: each replica keeps its own disjoint state behind the
Service, so keep `replicaCount: 1` (and `autoscaling.enabled: false`) whenever
you rely on Floci's own storage.

## Full mode (opt-in, not hardened)

The chart has a second, deliberately non-hardened mode for when you need the 10
Docker-backed services. `floci.mode=full` swaps the hardened image for the
separate `floci-full` image and reconfigures the pod so those services work:

- Runs the pod as root (`runAsNonRoot: false`, `runAsUser: 0`).
- Disables the read-only root filesystem (`readOnlyRootFilesystem: false`).
- Bind-mounts the host Docker socket `/var/run/docker.sock` into the pod (a
  `hostPath` volume) so Floci can drive the Docker daemon directly.
- Sets `LOCALSTACK_PARITY=true`.

This enables all 65 services: everything in hardened mode plus the 10
Docker-backed ones (Lambda, RDS, ElastiCache, MSK, ECS, EKS, OpenSearch, ECR,
DocumentDB, Neptune).

> ### Security warning
>
> Full mode is **not hardened**. It runs as **root** and mounts the **host
> Docker socket**, a node-root / container-escape surface: any code in the pod
> can control the node's Docker daemon and effectively owns the node. **Do not
> use full mode on shared or multi-tenant clusters.** It is an opt-in
> developer/CI convenience only.

Because of that, full mode requires an explicit acknowledgement or the chart
refuses to render:

```sh
helm install floci oci://ghcr.io/quenchworks/charts/floci \
  --set floci.mode=full \
  --set floci.full.acknowledgeRisk=true
```

Omitting `floci.full.acknowledgeRisk=true` (its default is `false`) makes
`helm template`/`helm install` fail with a message explaining the risk. To go
back to the safe default, set `floci.mode=hardened` (or drop the overrides).

## Configuration examples

Single-replica persistent storage:

```yaml
persistence:
  enabled: true
  size: 8Gi
floci:
  storage:
    mode: persistent   # or hybrid / wal
    path: /data
```

Pin a region and pass per-service config through env:

```yaml
floci:
  defaultRegion: eu-west-1
extraEnvVars:
  - name: FLOCI_SERVICES_S3_PORT
    value: "4566"
```

## Uninstall

```sh
helm uninstall floci
```

A PVC provisioned when `persistence.enabled=true` is retained by Kubernetes on
uninstall; delete it explicitly if you want the data gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=floci
```

## Notes

The default memory mode is ephemeral; keep `replicaCount: 1` whenever you rely
on Floci's own storage. Full mode is an opt-in, non-hardened developer/CI
convenience only. The chart depends on the `quench-common` library chart, pulled
from `oci://ghcr.io/quenchworks/charts/quench-common`. In the default hardened
mode the container runs nonroot on a read-only root filesystem with all
capabilities dropped, and the image is pinned by digest.

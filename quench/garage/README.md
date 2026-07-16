# Quenchworks Garage

Hardened [Garage](https://github.com/deuxfleurs-org/garage) on a minimal, nonroot,
0-CVE image pinned by digest and cosign-signed (keyless / Sigstore). Garage is an
S3-compatible object store (AGPL-3.0), single node, and the alternative to the
default Quenchworks object store, [SeaweedFS](https://github.com/quenchworks/charts).
One `garage server` process runs the store; the entrypoint seeds `garage.toml`,
applies a single-node layout, and imports the S3 key plus an optional default
bucket on first boot. The S3 API is served on port 3900; an unauthenticated admin
`/health` endpoint on 3903 backs the probes.

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/garage
```

By default an S3 admin access/secret key pair, an RPC secret, and an admin token
are generated and stored in a Secret (preserved across upgrades). The access key
is generated as `GK` + 24 hex chars, the format Garage requires.

Create a default bucket on first boot and size the data volume:

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/garage \
  --set config.defaultBucket=my-bucket \
  --set persistence.size=50Gi
```

## Connect

Garage uses an S3 region of `garage`, so pass `--region garage` to your client.

```bash
# S3 credentials
ACCESS_KEY=$(kubectl get secret objstore-garage -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-garage -o jsonpath="{.data.secret-key}" | base64 -d)
```

Use them with any S3 client, for example the AWS CLI from a pod in the cluster:

```bash
kubectl run awscli --rm -i --restart=Never --image=amazon/aws-cli \
  --env AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --env AWS_SECRET_ACCESS_KEY="$SECRET_KEY" -- \
  --endpoint-url http://objstore-garage:3900 --region garage s3 mb s3://my-bucket

# put / get an object
echo quench > /tmp/hello && aws --endpoint-url http://objstore-garage:3900 \
  --region garage s3 cp /tmp/hello s3://my-bucket/hello
aws --endpoint-url http://objstore-garage:3900 --region garage s3 cp s3://my-bucket/hello -
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/garage \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/garage --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/garage` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node (`garage server`, `replication_factor=1`). |
| `auth.enabled` | `true` | Generate + wire S3 / RPC / admin secrets. |
| `auth.accessKey` | (generated) | `GK` + 24 hex chars if empty; Garage rejects other formats. Stored in the Secret. |
| `auth.secretKey` | (generated) | 64-hex random if empty; stored in the Secret. |
| `auth.rpcSecret` | (generated) | 64-hex random if empty; cluster RPC secret. |
| `auth.adminToken` | (generated) | 64-hex random if empty; guards the admin API. |
| `auth.existingSecret` | `""` | Use an existing Secret for all four values. |
| `auth.existingSecretAccessKeyKey` | `access-key` | Key in the existing Secret. |
| `auth.existingSecretSecretKeyKey` | `secret-key` | Key in the existing Secret. |
| `auth.existingSecretRpcSecretKey` | `rpc-secret` | Key in the existing Secret. |
| `auth.existingSecretAdminTokenKey` | `admin-token` | Key in the existing Secret. |
| `config.defaultBucket` | `""` | Create + grant this bucket to the admin key on first boot. |
| `config.zone` | `dc1` | Layout zone for the single node. |
| `config.capacity` | `1G` | Declared capacity for the single node. |
| `persistence.enabled` | `true` | PVC at `/data` (metadata, data, garage.toml). |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC. |
| `resources.requests` | `250m / 512Mi` | CPU / memory requests. |
| `resources.limits` | `2 / 2Gi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `3900` | S3 API (service port name `s3`). |
| `service.adminPort` | `3903` | Admin API (`/health`); reachable in-cluster for the probe. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to S3, and to admin from the release's own pods. |
| `networkPolicy.allowExternal` | `false` | Restrict S3 to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (`podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`extraEnvVars`, `extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
security contexts, probe overrides, update strategy); extra `garage server` flags
pass through `args`.

## Architecture

Garage runs as a single-replica StatefulSet with a PVC mounted at `/data` (holding
the metadata store, object data, and the seeded `garage.toml`) via a
`volumeClaimTemplate`. The entrypoint seeds the config, applies a single-node
layout (`replication_factor=1`) using `config.zone` and `config.capacity`, and
imports the S3 access key as the admin key on first boot; with
`config.defaultBucket` set it also creates that bucket and grants it to the key.

Two ports are exposed: S3 on 3900 (service port name `s3`) and the admin API on
3903. The admin `/health` endpoint is unauthenticated and returns 200 once the
node is up and the layout is applied, which backs the liveness and readiness
probes (initial delays are generous because the first-boot layout bootstrap takes
about 10 to 30 seconds). The container runs nonroot on a read-only root filesystem
with all capabilities dropped.

The four secrets (S3 access/secret key, RPC secret, admin token) are generated
into a Secret and preserved across upgrades. Supply your own via `auth.*` or point
at an existing Secret with `auth.existingSecret`.

## Configuration examples

Bring your own S3 credentials and RPC secret (the access key must be `GK` + 24 hex
chars or `garage key import` rejects it):

```yaml
auth:
  accessKey: "GK0123456789abcdef01234567"
  secretKey: "<64 hex chars>"
  rpcSecret: "<64 hex chars>"
  adminToken: "<64 hex chars>"
```

Or reuse an existing Secret and raise the declared capacity:

```yaml
auth:
  existingSecret: garage-creds
config:
  capacity: "100G"
persistence:
  size: 100Gi
  storageClass: fast-ssd
```

## Uninstall

```bash
helm uninstall objstore
```

The PVC provisioned by the StatefulSet's `volumeClaimTemplate` is retained on
uninstall. Delete it explicitly to remove the stored objects and metadata:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=objstore
```

## Notes

Single node only (`replication_factor=1`): this chart runs one `garage server`
process with a single-node layout, so it is not the geo-distributed, multi-node
topology Garage also supports. For that you would run multiple nodes and manage
the layout yourself, tracked as a follow-up. The chart depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

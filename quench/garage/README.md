# Quenchworks Garage

Hardened [Garage](https://github.com/deuxfleurs-org/garage) on a minimal,
nonroot, 0-CVE image pinned by digest. Garage is an **S3-compatible object
store** (AGPL-3.0), single node — the **alternative to the default Quenchworks
object store, [SeaweedFS](https://github.com/quenchworks/charts)**. One `garage
server` process runs the store; the entrypoint seeds `garage.toml`, applies a
single-node layout, and imports the S3 key + an optional default bucket on first
boot. The S3 API is served on port `3900`; an unauthenticated admin `/health`
endpoint on `3903` backs the probes.

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/garage
```

By default an S3 admin access/secret key pair, an RPC secret, and an admin token
are generated and stored in a Secret (preserved across upgrades). The access key
is generated as `GK` + 24 hex chars, which is the format Garage requires.

## Connect

Garage uses an S3 **region of `garage`** — pass `--region garage` to your client.

```bash
# S3 credentials
ACCESS_KEY=$(kubectl get secret objstore-garage -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-garage -o jsonpath="{.data.secret-key}" | base64 -d)
```

Use them with any S3 client — for example the AWS CLI from a pod in the cluster:

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

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/garage` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
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
| `persistence.size` | `8Gi` | |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.existingClaim` | `""` | Bind an existing PVC. |
| `resources` | requests 250m/512Mi, limits 2/2Gi | |
| `service.type` | `ClusterIP` | |
| `service.port` | `3900` | The S3 API (service port name `s3`). |
| `service.adminPort` | `3903` | The admin API (`/health`); reachable in-cluster for the probe. |
| `serviceAccount.create` | `true` | |
| `rbac.create` | `false` | |
| `networkPolicy.enabled` | `true` | Ingress to S3, and to admin from the release's own pods. |
| `networkPolicy.allowExternal` | `false` | Restrict S3 to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Common production knobs (`extraEnvVars`, `extraVolumes`, `initContainers`,
`sidecars`, `nodeSelector`, `affinity`, `tolerations`, probe overrides, security
contexts, …) are wired through `quench-common`; extra `garage server` flags pass
through `args`.

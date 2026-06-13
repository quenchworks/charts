# Quenchworks SeaweedFS

Hardened [SeaweedFS](https://github.com/seaweedfs/seaweedfs) on a minimal,
nonroot, 0-CVE image pinned by digest. This is **the default Quenchworks object
store** — S3-compatible, single node (MinIO gutted its community edition in
2025). The single `weed` binary is built from source on Wolfi and runs in the
single-process `weed server -s3` model: master + volume + filer + the S3 gateway
in one process. The S3 API is served on port `8333`.

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/seaweedfs
```

By default S3 auth is enabled: an admin access/secret key pair is generated and
stored in a Secret (preserved across upgrades), and the entrypoint enables S3
auth. Set `auth.enabled=false` to run S3 open/anonymous (the NetworkPolicy is
then the only boundary).

## Connect

```bash
# S3 credentials
ACCESS_KEY=$(kubectl get secret objstore-seaweedfs -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-seaweedfs -o jsonpath="{.data.secret-key}" | base64 -d)
```

Use them with any S3 client — for example the AWS CLI from a pod in the cluster:

```bash
kubectl run awscli --rm -i --restart=Never --image=amazon/aws-cli \
  --env AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --env AWS_SECRET_ACCESS_KEY="$SECRET_KEY" -- \
  --endpoint-url http://objstore-seaweedfs:8333 s3 mb s3://my-bucket

# put / get an object
echo quench > /tmp/hello && aws --endpoint-url http://objstore-seaweedfs:8333 \
  s3 cp /tmp/hello s3://my-bucket/hello
aws --endpoint-url http://objstore-seaweedfs:8333 s3 cp s3://my-bucket/hello -
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/seaweedfs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/seaweedfs` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node (single-process `weed server -s3`). |
| `auth.enabled` | `true` | Generate keys + enable S3 auth. `false` => open/anonymous. |
| `auth.accessKey` | (generated) | 20-char random if empty; stored in the Secret. |
| `auth.secretKey` | (generated) | 40-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the access/secret keys. |
| `auth.existingSecretAccessKeyKey` | `access-key` | Key in the existing Secret. |
| `auth.existingSecretSecretKeyKey` | `secret-key` | Key in the existing Secret. |
| `persistence.enabled` | `true` | PVC at `/data`. |
| `persistence.size` | `8Gi` | |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.existingClaim` | `""` | Bind an existing PVC. |
| `resources` | requests 250m/512Mi, limits 2/2Gi | |
| `service.type` | `ClusterIP` | |
| `service.port` | `8333` | The S3 API (service port name `s3`). |
| `serviceAccount.create` | `true` | |
| `rbac.create` | `false` | |
| `networkPolicy.enabled` | `true` | Ingress to the S3 port only. |
| `networkPolicy.allowExternal` | `false` | Restrict to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Common production knobs (`extraEnvVars`, `extraVolumes`, `initContainers`,
`sidecars`, `nodeSelector`, `affinity`, `tolerations`, probe overrides, security
contexts, …) are wired through `quench-common`; extra `weed server` flags pass
through `args`.

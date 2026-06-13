# Quenchworks RustFS

Hardened [RustFS](https://github.com/rustfs/rustfs) on a minimal, nonroot, 0-CVE
image pinned by digest. RustFS is a Rust, S3-compatible, MinIO-alternative object
store — the **newest** S3-compatible option in the Quenchworks catalog.

> **BETA / preview.** RustFS has not cut a stable release yet; this chart pins the
> latest published pre-release (`1.0.0_beta8`). For a stable default object store,
> use the Quenchworks **SeaweedFS** chart — RustFS and Garage are the alternatives.

The upstream musl-static binary is hardened on Wolfi and runs single node as
`rustfs server <VOLUMES>`. The S3 API is served on port `9000`. The web console
(port `9001`) is opt-in and off by default (S3-only).

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/rustfs
```

By default S3 auth is enabled: a root access/secret key pair is generated and
stored in a Secret (preserved across upgrades) and wired into the container as
`RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`. Set `auth.enabled=false` to fall back to
RustFS's built-in default identity (`rustfsadmin`/`rustfsadmin`); the NetworkPolicy
is then the only boundary.

## Connect

```bash
# S3 credentials
ACCESS_KEY=$(kubectl get secret objstore-rustfs -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-rustfs -o jsonpath="{.data.secret-key}" | base64 -d)
```

Use them with any S3 client — for example the AWS CLI from a pod in the cluster:

```bash
kubectl run awscli --rm -i --restart=Never --image=amazon/aws-cli \
  --env AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --env AWS_SECRET_ACCESS_KEY="$SECRET_KEY" -- \
  --endpoint-url http://objstore-rustfs:9000 s3 mb s3://my-bucket

# put / get an object
echo quench > /tmp/hello && aws --endpoint-url http://objstore-rustfs:9000 \
  s3 cp /tmp/hello s3://my-bucket/hello
aws --endpoint-url http://objstore-rustfs:9000 s3 cp s3://my-bucket/hello -
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rustfs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/rustfs` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node. |
| `auth.enabled` | `true` | Generate keys + wire root creds. `false` => built-in default identity. |
| `auth.accessKey` | (generated) | 20-char random if empty; stored in the Secret. |
| `auth.secretKey` | (generated) | 40-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the access/secret keys. |
| `auth.existingSecretAccessKeyKey` | `access-key` | Key in the existing Secret. |
| `auth.existingSecretSecretKeyKey` | `secret-key` | Key in the existing Secret. |
| `console.enabled` | `false` | Opt-in web console on port `9001`. |
| `console.port` | `9001` | Console port (service + container) when enabled. |
| `persistence.enabled` | `true` | PVC at `/data` (object data). |
| `persistence.size` | `8Gi` | |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.existingClaim` | `""` | Bind an existing PVC. |
| `resources` | requests 250m/512Mi, limits 2/2Gi | |
| `service.type` | `ClusterIP` | |
| `service.port` | `9000` | The S3 API (service port name `s3`). |
| `serviceAccount.create` | `true` | |
| `rbac.create` | `false` | |
| `networkPolicy.enabled` | `true` | Ingress to the S3 port (+ console if enabled). |
| `networkPolicy.allowExternal` | `false` | Restrict to in-cluster pods. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Common production knobs (`extraEnvVars`, `extraVolumes`, `initContainers`,
`sidecars`, `nodeSelector`, `affinity`, `tolerations`, probe overrides, security
contexts, …) are wired through `quench-common`; extra `rustfs server` flags pass
through `args`.

> **Young-project note:** RustFS emits benign ERROR lines at boot (an expired-TLS
> remote check and transient `AccessDenied` during init). These are not failures —
> the `/health` probe on port `9000` is the source of truth for readiness.

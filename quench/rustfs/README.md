# Quenchworks RustFS

Hardened [RustFS](https://github.com/rustfs/rustfs) on a minimal, nonroot, 0-CVE
image pinned by digest and cosign-signed (keyless / Sigstore). RustFS is a Rust,
S3-compatible, MinIO-alternative object store — the newest S3-compatible option
in the Quenchworks catalog. The upstream musl-static binary is hardened on Wolfi
and runs single node as `rustfs server <VOLUMES>` on a read-only root filesystem
with all capabilities dropped, serving the S3 API on port 9000. The web console
(port 9001) is opt-in and off by default (S3-only).

> **BETA / preview.** RustFS has not cut a stable release yet; this chart pins the
> latest published pre-release (`1.0.0_beta7`). For a stable default object store,
> use the Quenchworks **SeaweedFS** chart — RustFS and Garage are the alternatives.

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/rustfs
```

By default S3 auth is enabled: a root access/secret key pair is generated and
stored in a Secret (preserved across upgrades) and wired into the container as
`RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`. Set `auth.enabled=false` to fall back to
RustFS's built-in default identity (`rustfsadmin`/`rustfsadmin`); the
NetworkPolicy is then the only boundary.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rustfs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/rustfs \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/rustfs` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node. |
| `auth.enabled` | `true` | Generate keys + wire root creds. `false` uses the built-in default identity. |
| `auth.accessKey` | (generated) | 20-char random if empty; stored in the Secret. |
| `auth.secretKey` | (generated) | 40-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the access/secret keys. |
| `auth.existingSecretAccessKeyKey` | `access-key` | Access-key field in the existing Secret. |
| `auth.existingSecretSecretKeyKey` | `secret-key` | Secret-key field in the existing Secret. |
| `console.enabled` | `false` | Opt-in web console on port `9001`. |
| `console.port` | `9001` | Console port (service + container) when enabled. |
| `persistence.enabled` | `true` | PVC mounted at `/data` (object data). |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `250m / 512Mi` | CPU / memory requests. |
| `resources.limits` | `2 / 2Gi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `9000` | The S3 API (service port name `s3`). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to the S3 port (+ console if enabled). |
| `networkPolicy.allowExternal` | `false` | Restrict to in-cluster pods; `true` opens ingress. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `podSecurityContext`, `containerSecurityContext`,
and the probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`). Extra
`rustfs server` flags pass through `args`.

## Architecture

RustFS runs as a **StatefulSet** so the node keeps a stable network identity and
its own persistent volume. One `rustfs server <VOLUMES>` process serves the S3
API on port 9000 (`s3`); the optional web console on port 9001 is off by default.
Object data lives on a PVC mounted at `/data`, provisioned via a
`volumeClaimTemplate`; the container root filesystem is read-only, with `/tmp` as
a writable `emptyDir`. The `/health` endpoint on port 9000 is unauthenticated and
returns 200 — it backs both the liveness and readiness probes.

Single node: RustFS runs one server process with local storage, so keep
`replicaCount` at 1.

## Configuration examples

Read the generated S3 credentials from the managed Secret and drive the API with
any S3 client — for example the AWS CLI from a pod in the cluster:

```bash
# S3 credentials
ACCESS_KEY=$(kubectl get secret objstore-rustfs -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-rustfs -o jsonpath="{.data.secret-key}" | base64 -d)

# make a bucket
kubectl run awscli --rm -i --restart=Never --image=amazon/aws-cli \
  --env AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --env AWS_SECRET_ACCESS_KEY="$SECRET_KEY" -- \
  --endpoint-url http://objstore-rustfs:9000 s3 mb s3://my-bucket

# put / get an object
echo quench > /tmp/hello && aws --endpoint-url http://objstore-rustfs:9000 \
  s3 cp /tmp/hello s3://my-bucket/hello
aws --endpoint-url http://objstore-rustfs:9000 s3 cp s3://my-bucket/hello -
```

Turn on the opt-in web console (served on port 9001):

```yaml
console:
  enabled: true
```

## Uninstall

```bash
helm uninstall objstore
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the object data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=objstore
```

## Notes

RustFS is a BETA/preview project with no stable release yet — validate carefully
before relying on it, and prefer the Quenchworks SeaweedFS chart for a stable
default object store. At boot RustFS emits benign ERROR lines (an expired-TLS
remote check and transient `AccessDenied` during init); these are not failures —
the `/health` probe on port 9000 is the source of truth for readiness. The chart
depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned
by digest.

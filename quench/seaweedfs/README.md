# Quenchworks SeaweedFS

Hardened [SeaweedFS](https://github.com/seaweedfs/seaweedfs) on a minimal,
nonroot, 0-CVE image, cosign-signed (keyless / Sigstore) and pinned by digest.
This is the default Quenchworks object store: S3-compatible and single node
(MinIO gutted its community edition in 2025). The single `weed` binary is built
from source on Wolfi and runs in the single-process `weed server -s3` model —
master, volume, filer, and the S3 gateway in one process. The S3 API is served
on port `8333`.

## Install

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/seaweedfs
```

By default S3 auth is enabled: an admin access/secret key pair is generated and
stored in a Secret (preserved across upgrades), and the entrypoint enables S3
auth. Set `auth.enabled=false` to run S3 open/anonymous (the NetworkPolicy is
then the only boundary).

Size the data volume and pick a storage class:

```bash
helm install objstore oci://ghcr.io/quenchworks/charts/seaweedfs \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/seaweedfs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/seaweedfs \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/seaweedfs` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single node (single-process `weed server -s3`). |
| `auth.enabled` | `true` | Generate keys + enable S3 auth. `false` runs open/anonymous. |
| `auth.accessKey` | (generated) | 20-char random if empty; stored in the Secret. |
| `auth.secretKey` | (generated) | 40-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the access/secret keys. |
| `auth.existingSecretAccessKeyKey` | `access-key` | Key in the existing Secret. |
| `auth.existingSecretSecretKeyKey` | `secret-key` | Key in the existing Secret. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/data`. |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 250m / mem 512Mi` | |
| `resources.limits` | `cpu 2 / mem 2Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8333` | The S3 API (service port name `s3`). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to the S3 port only. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow S3 ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy); extra
`weed server` flags pass through `args` (e.g. `["-volume.max=0"]`).

## Architecture

SeaweedFS runs as a **StatefulSet** so the single node keeps a stable network
identity over the headless service and its own persistent volume. All four roles
— master, volume, filer, and the S3 gateway — run together in one `weed server
-s3` process. State lives on a PVC mounted at `/data`, provisioned via a
`volumeClaimTemplate`. The container runs nonroot on a read-only root filesystem
with all capabilities dropped.

The **S3 API (8333)** is the only exposed port. Liveness and readiness both
`httpGet /healthz` on it; that endpoint is unauthenticated and returns 200 even
with S3 auth enabled, so probes work regardless of `auth.enabled`. When
`auth.enabled` is on, the entrypoint writes an identities config granting the
admin key full access and turns S3 auth on, sourcing the keys from the Secret
(generated when not provided, or `auth.existingSecret`).

## Configuration examples

Read the generated credentials and use them with any S3 client from a pod in the
cluster:

```bash
ACCESS_KEY=$(kubectl get secret objstore-seaweedfs -o jsonpath="{.data.access-key}" | base64 -d)
SECRET_KEY=$(kubectl get secret objstore-seaweedfs -o jsonpath="{.data.secret-key}" | base64 -d)

kubectl run awscli --rm -i --restart=Never --image=amazon/aws-cli \
  --env AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --env AWS_SECRET_ACCESS_KEY="$SECRET_KEY" -- \
  --endpoint-url http://objstore-seaweedfs:8333 s3 mb s3://my-bucket
```

Bring your own credentials from an existing Secret:

```yaml
auth:
  enabled: true
  existingSecret: my-s3-creds
  existingSecretAccessKeyKey: access-key
  existingSecretSecretKeyKey: secret-key
```

Pass extra `weed server` flags (for example, unlimited volume growth):

```yaml
args:
  - -volume.max=0
```

## Uninstall

```bash
helm uninstall objstore
```

The PVC provisioned by the `volumeClaimTemplate` and the credentials Secret are
retained by Kubernetes on uninstall — delete them explicitly if you want the data
and keys gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=objstore
kubectl delete secret objstore-seaweedfs
```

## Notes

Single node by default — this is the S3-compatible object store for the
Quenchworks catalog, not a distributed cluster. Auth is on by default; leave it
on and keep the NetworkPolicy as the trust boundary before exposing S3 beyond the
cluster. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned
by digest.

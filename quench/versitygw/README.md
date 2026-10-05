# Quenchworks Versity S3 Gateway

Hardened [Versity S3 Gateway](https://github.com/versity/versitygw), an
S3-compatible API server. By default it serves the posix backend: each bucket is
a directory on a PVC mounted at `/data`. The same image can front another S3
service or Azure Blob by changing `backendArgs`. It runs as a single-replica
StatefulSet on port 7070 with `GET /health` for probes. The image is minimal,
runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped, ships 0-CVE, is cosign-signed (keyless / Sigstore), and the chart pins
it by the signed digest, never a tag.

## Install

```bash
helm install s3 oci://ghcr.io/quenchworks/charts/versitygw
```

The root access key and secret key are generated on first install and kept on
upgrade. Read them back:

```bash
kubectl get secret s3-versitygw -o jsonpath='{.data.access-key}' | base64 -d; echo
kubectl get secret s3-versitygw -o jsonpath='{.data.secret-key}' | base64 -d; echo
```

Use your own Secret instead (keys `access-key` and `secret-key` by default):

```bash
helm install s3 oci://ghcr.io/quenchworks/charts/versitygw \
  --set auth.existingSecret=my-s3-root
```

Then point any S3 client at the Service:

```bash
kubectl port-forward svc/s3-versitygw 7070:7070
aws --endpoint-url http://127.0.0.1:7070 s3 mb s3://demo
```

Front another backend, for example an upstream S3 service:

```yaml
backendArgs: ["s3", "--endpoint", "https://s3.example.com", "--access", "...", "--secret", "..."]
persistence:
  enabled: false
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/versitygw \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/versitygw --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `auth.accessKey`, `auth.secretKey` | `""` | Root account. Empty: generated on first install, kept on upgrade. |
| `auth.existingSecret` | `""` | Use a Secret you manage; key names in `auth.existingSecretAccessKeyKey` / `auth.existingSecretSecretKeyKey`. |
| `backendArgs` | `["posix", "/data"]` | Backend subcommand and its arguments. |
| `globalArgs` | `[]` | Gateway flags placed before the backend (`--region`, `--iam-dir`, ...). `--port` and `--health` are always set. |
| `containerPort` | `7070` | Listen port. |
| `persistence.enabled` / `.size` | `true` / `8Gi` | PVC at `/data` for the posix backend. `existingClaim` binds your own. |
| `service.type` / `.port` | `ClusterIP` / `7070` | |
| `networkPolicy.enabled` / `.allowExternal` | `true` / `false` | Default admits clients from the release namespace only. |
| `replicaCount` | `1` | The posix backend owns one data dir; keep 1. |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides,
security contexts) work as in every Quenchworks chart.

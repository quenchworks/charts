# Quenchworks tusd

Hardened [tusd](https://github.com/tus/tusd), the reference server for the
[tus](https://tus.io) resumable-upload protocol. A client that loses its connection asks tusd
for the current offset and continues from there instead of starting over. Uploads go to a
volume or an S3-compatible bucket, and hooks can notify your app. The image is built from
source, runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install uploads oci://ghcr.io/quenchworks/charts/tusd
# S3 instead of a volume
kubectl create secret generic tusd-s3 --from-literal=AWS_ACCESS_KEY_ID=... \
  --from-literal=AWS_SECRET_ACCESS_KEY=... --from-literal=AWS_REGION=us-east-1
helm install uploads oci://ghcr.io/quenchworks/charts/tusd --set s3.bucket=my-uploads --set s3.existingSecret=tusd-s3
```

Clients upload to `http://uploads-tusd:8080/files/`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `persistence.enabled`, `persistence.size` | `true`, `10Gi` | Disk store on a PVC at `/data` |
| `s3.bucket`, `s3.endpoint`, `s3.existingSecret` | `""` | S3 store instead of the disk |
| `basePath` | `/files/` | Upload URL path |
| `behindProxy` | `false` | Trust `X-Forwarded-*` from an ingress for upload URLs |
| `tls.enabled` | `false` | TLS on 8080 (existing Secret, cert-manager, or self-signed) |
| `extraArgs` | `[]` | More flags: `-max-size`, `-hooks-http`, `-cors-allow-origin` |

With the disk store keep one replica (Recreate strategy, one ReadWriteOnce volume); with S3,
replicas share the bucket.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tusd \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

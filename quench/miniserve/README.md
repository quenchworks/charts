# Quenchworks miniserve

Hardened [miniserve](https://github.com/svenstaro/miniserve): a small file server with directory
listing, uploads, mkdir, archive downloads (tar, tar.gz, zip), basic auth, QR codes and native TLS. The
image is built from source with cargo auditable (so scanners see every crate); it runs as uid 1001 and
is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/miniserve --set uploads.enabled=true --set tls.enabled=true
kubectl get secret files-miniserve -o jsonpath='{.data.password}' | base64 -d   # basic auth, user admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled` | `true` | HTTP basic auth on every path |
| `auth.username` | `admin` | The basic auth user |
| `auth.password`, `auth.existingSecret` | generated | The password, or a Secret with key `password` |
| `uploads.enabled`, `uploads.dirs` | `false`, `["/"]` | Uploads and mkdir into these directories of the volume |
| `tls.enabled` | `false` | Native TLS on the same port (existingSecret, cert-manager or a Helm-generated CA) |
| `settings` | `{}` | More `MINISERVE_*` variables, e.g. `MINISERVE_ENABLE_ZIP`, `MINISERVE_QRCODE`, `MINISERVE_TITLE` |
| `persistence.size` | `5Gi` | The files served from `/srv` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/miniserve \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

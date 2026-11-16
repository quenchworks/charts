# Quenchworks MicroBin

Hardened [MicroBin](https://github.com/szabodanika/microbin): a small pastebin and file-sharing server
with private, read-only and encrypted uploads, expiry, QR codes and an admin page, on SQLite. The image
is built from source with cargo auditable (so scanners see every crate) against Wolfi OpenSSL; it runs as
uid 1001 with telemetry and update checks off, and is CVE-gated at build, cosign-signed and pinned by
digest.

## Install

```bash
helm install paste oci://ghcr.io/quenchworks/charts/microbin --set publicPath=https://paste.example.com
kubectl get secret paste-microbin -o jsonpath='{.data.password}' | base64 -d   # /admin, user admin
```

MicroBin has no TLS listener: expose it through an ingress or gateway with TLS and set `publicPath` to
that URL (share links and QR codes use it).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The admin page user |
| `admin.password`, `admin.existingSecret` | generated | The admin password (replaces upstream's default `m1cr0b1n`), or a Secret with key `password` |
| `publicPath` | `""` | The public URL (`MICROBIN_PUBLIC_PATH`) |
| `settings` | `{}` | More `MICROBIN_*` variables, e.g. `MICROBIN_PRIVATE`, `MICROBIN_DEFAULT_EXPIRY`, `MICROBIN_QR` |
| `extraEnvVarsSecret` | `""` | A Secret of variables, e.g. `MICROBIN_UPLOADER_PASSWORD` to require a password for uploads |
| `persistence.size` | `5Gi` | The SQLite database and uploaded files |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/microbin \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

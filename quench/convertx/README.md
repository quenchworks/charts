# Quenchworks ConvertX

Hardened [ConvertX](https://github.com/C4illin/ConvertX): a self-hosted file converter with a web UI for images,
video, audio and office documents. The image compiles the Bun app from source and carries ImageMagick,
GraphicsMagick, FFmpeg, LibreOffice, libheif, libjxl, Poppler and Potrace from Wolfi; converters whose tools Wolfi
does not package (pandoc, Inkscape, Calibre and others) are left out of the UI. It runs as uid 1001 on a read-only
root filesystem and is CVE-gated at build, cosign-signed and pinned by digest.

Upstream lets the first visitor register the first account. This chart claims it with a post-install Job instead.

## Install

```bash
helm install convert oci://ghcr.io/quenchworks/charts/convertx --set auth.email=you@example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=convert.example.com' \
  --set 'ingress.tls[0].hosts[0]=convert.example.com' --set 'ingress.tls[0].secretName=convert-tls'
kubectl get secret convert-convertx -o jsonpath='{.data.password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.email`, `auth.password` | `admin@example.com`, generated | The first account, claimed by the Job |
| `auth.existingSecret` | `""` | A Secret with `password` and `jwt-secret` instead |
| `accountRegistration` | `false` | Let more people register |
| `httpAllowed` | `false` | Allow sign-in over plain HTTP (cookies lose the Secure flag) |
| `autoDeleteEveryNHours` | `24` | Delete finished conversions after this many hours (`0` keeps them) |
| `settings` | `{}` | More ConvertX settings (`MAX_CONVERT_PROCESS`, `FFMPEG_ARGS`, `LANGUAGE`) |
| `persistence.size` | `10Gi` | `/app/data`: the database, uploads and converted files |
| `resources.limits` | `4` CPU, `4Gi` | LibreOffice and FFmpeg conversions are heavy |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/convertx \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

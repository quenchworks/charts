# Quenchworks Grav

Hardened [Grav](https://github.com/getgrav/grav): a flat-file CMS with a web admin, Markdown pages, themes
and plugins, no database. The image runs the grav-admin release on Wolfi php-8.5-fpm and QuenchWorks' nginx
with upstream's deny rules; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install site oci://ghcr.io/quenchworks/charts/grav --set admin.email=you@example.com
kubectl get secret site-grav -o jsonpath='{.data.admin-password}' | base64 -d   # /admin, user admin
```

The site's pages, config, accounts and data live on the volume; plugins and themes ship in the image, so
an image update reaches them. Installing plugins through GPM is not possible on the read-only image.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email`, `admin.fullname` | `admin`, `admin@example.com`, `Admin` | The first admin |
| `admin.password` | generated | Must meet Grav's policy (8+ characters, a digit, a lower and an upper case letter) |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `1Gi` | The site content and caches |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/grav \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

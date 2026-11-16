# Quenchworks Lychee

Hardened [Lychee](https://github.com/LycheeOrg/Lychee): photo management with albums, sharing, smart albums,
EXIF and map views and a REST API. The image runs the release on Wolfi php-8.5-fpm and QuenchWorks' nginx
with Laravel and the Symfony http stack raised to fixed releases; it runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install photos oci://ghcr.io/quenchworks/charts/lychee --set appURL=https://photos.example.com
kubectl get secret photos-lychee -o jsonpath='{.data.admin-password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.password` | `admin`, generated | The admin made on the first start |
| `appKey.value`, `appKey.existingSecret` | generated | APP_KEY (`base64:` + 32 bytes), kept across upgrades |
| `appURL` | `""` | The public URL (APP_URL) |
| `settings` | `{}` | More environment: TIMEZONE, TRUSTED_PROXIES, DB_* for MySQL or PostgreSQL |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `20Gi` | storage/ with the SQLite database, and the photos |

Thumbnails are made with GD (no ImageMagick in the image), and there is no ffmpeg for video thumbnails.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/lychee \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

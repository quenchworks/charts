# Quenchworks Koel

Hardened [Koel](https://github.com/koel/koel): a personal music streaming server with a web player,
playlists, podcasts and a Subsonic-compatible API. The image runs the release on Wolfi php-8.5-fpm and
QuenchWorks' nginx with Laravel and its vulnerable libraries raised to fixed releases; it runs as uid 1001
and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install music oci://ghcr.io/quenchworks/charts/koel --set admin.email=you@example.com
kubectl get secret music-koel -o jsonpath='{.data.admin-password}' | base64 -d
```

Copy music into the `/music` volume, then run `php /var/www/koel/artisan koel:scan` in the pod (or
upload through the web player).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.name`, `admin.email`, `admin.password` | `Admin`, `admin@example.com`, generated | The first admin, made when there are no users |
| `appKey.value`, `appKey.existingSecret` | generated | APP_KEY (`base64:` + 32 bytes), kept across upgrades |
| `appURL` | `""` | The public URL (APP_URL) |
| `music.enabled`, `music.size`, `music.existingClaim` | `true`, `20Gi`, `""` | The library volume at `/music` (kept on uninstall) |
| `settings` | `{}` | More environment: TZ, LASTFM_API_KEY, DB_* for MySQL or PostgreSQL |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `5Gi` | storage/: SQLite database, artwork, search indexes |

No transcoding: ffmpeg is not in the image, so play formats the browser supports.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/koel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

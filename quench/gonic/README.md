# Quenchworks gonic

Hardened [gonic](https://github.com/sentriz/gonic), a lightweight music streaming server with a Subsonic
API, so Subsonic, Airsonic and DSub style apps can stream your library, with podcasts, playlists and
on-the-fly transcoding. The image is built from source (pure Go) with ffmpeg for transcoding; it runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install music oci://ghcr.io/quenchworks/charts/gonic --set music.existingClaim=my-music
kubectl get secret music-gonic -o jsonpath='{.data.admin-password}' | base64 -d
```

gonic seeds its admin account with the password `admin` and has no setting to change it, so a
post-install Job sets the generated password through the admin form (and re-checks it on every upgrade).
The library is mounted read-only; the database, podcasts and playlists live on the chart's volume.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `music.existingClaim` | `""` | A PVC with your music, mounted read-only at `/music` |
| `admin.existingSecret` | `""` | A Secret with `admin-password` instead of a generated one |
| `scanIntervalMinutes` | `60` | Periodic library rescans (0 turns them off) |
| `persistence.size` | `5Gi` | Database, podcasts and playlists |
| `settings` | `{}` | More `GONIC_*` environment variables |

Jukebox mode (playback on the server through mpv) is not in the image.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gonic \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

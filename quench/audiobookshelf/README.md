# Quenchworks Audiobookshelf

Hardened [Audiobookshelf](https://github.com/advplyr/audiobookshelf), a self-hosted audiobook and podcast server
with progress sync across the web and mobile apps, podcast downloads, metadata matching and an ebook reader. The
image is built from source on Wolfi Node 24 with sqlite3 linked to Wolfi's SQLite and Wolfi ffmpeg; it runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install books oci://ghcr.io/quenchworks/charts/audiobookshelf --set media.existingClaim=my-audiobooks
kubectl get secret books-audiobookshelf -o jsonpath='{.data.root-password}' | base64 -d
```

Until its setup form is posted, Audiobookshelf lets anyone who reaches it create the root account. A post-install
Job claims it right away with the generated password (`root`); it never changes an existing root. The database and
metadata (covers, cache, backups) live on the chart's volume; your media is mounted at `/media`, where you add
libraries in the web UI.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `media.existingClaim` | `""` | A PVC with your audiobooks and podcasts, mounted at `/media` |
| `media.readOnly` | `false` | Mount it read-only (podcast downloads and uploads then fail) |
| `root.existingSecret` | `""` | A Secret with `root-password` instead of a generated one |
| `persistence.size` | `10Gi` | Database, covers, cache and backups |
| `settings` | `{}` | More environment variables, e.g. `ROUTER_BASE_PATH` |

The optional nunicode SQLite extension (Unicode-aware case folding in sorting and search) is not in the image;
SQLite's own folding is used.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/audiobookshelf \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

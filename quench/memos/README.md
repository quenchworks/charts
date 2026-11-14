# Quenchworks Memos

Hardened [Memos](https://github.com/usememos/memos), a self-hosted note-taking and micro-journal
server: Markdown memos, tags, a timeline, attachments and an API. The image is one CGO-free Go
binary built from source with the pnpm-built web app embedded, runs as uid 1001 and is CVE-gated
at build, cosign-signed and pinned by digest.

## Install

```bash
helm install notes oci://ghcr.io/quenchworks/charts/memos
kubectl get secret notes-memos-admin -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/notes-memos 5230
```

Log in as `admin` at `http://localhost:5230`. Upstream Memos makes the first person who signs up
the admin; this chart instead declares the admin in Memos' configuration directory
(`/etc/memos/config`), so a fresh install has no open first sign-up. Memos sets the password
once (`writeOnlyVersion`); change it in the UI afterwards. Self sign-up stays open as upstream
ships it (new accounts get role USER); turn it off under Settings, General.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.password` | `admin`, generated | Declared admin; password set on the first apply |
| `database.driver`, `database.existingSecret` | `""` (SQLite) | `postgres` or `mysql` with a Secret holding the DSN (key `database.dsnKey`) |
| `settings` | `{}` | Memos options as `MEMOS_*` env (`MEMOS_INSTANCE_URL`, ...) |
| `persistence.size` | `2Gi` | Data volume: SQLite and local attachments |

One replica: the data volume is ReadWriteOnce and the Deployment uses Recreate.

## Image uploads and CVE-2023-36308

Memos strips EXIF from uploaded images with `disintegration/imaging` 1.6.2, which has no fixed
release for CVE-2023-36308. The image floors `golang.org/x/image` at a release whose decoders
reject the crafted palettes that trigger it and patches imaging's palette table at build time;
the image's VEX statement records the evidence.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/memos \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

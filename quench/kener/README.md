# Quenchworks Kener

Hardened [Kener](https://github.com/rajnandan1/kener): a status page and incident manager with HTTP, TCP, DNS, ping
and SSL monitors, incidents, maintenance windows and badges. The image builds Kener from source on Wolfi Node 24
with its native modules compiled locally; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at
build, cosign-signed and pinned by digest. Four SvelteKit advisories fixed only in SvelteKit 3 do not reach Kener
(it uses no remote functions, no `use:enhance` and no prerendering); they are documented in a VEX statement.

The chart keeps Kener's SQLite database on a PersistentVolumeClaim, runs on the bundled QuenchWorks Valkey (Kener v4
needs Redis) and generates `KENER_SECRET_KEY` once. Database migrations and the seed run at start.

## Install

```bash
helm install status oci://ghcr.io/quenchworks/charts/kener \
  --set origin=https://status.example.com
```

`origin` is required: it is the public URL Kener is served at, and SvelteKit refuses form posts (sign-in included)
whose Origin differs. Open the site and sign up: **the first account becomes the admin**, and Kener refuses every
later sign-up, so create it right after install.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `origin` | `""` | Public URL (`scheme://host[:port]`), required |
| `persistence.size` | `2Gi` | SQLite volume at `/app/database` |
| `persistence.existingClaim` | `""` | Use your own PVC |
| `secret.existingSecret` | `""` | Secret with key `secret-key` instead of the generated one |
| `valkey.enabled` | `true` | Bundled Valkey with a generated password |
| `externalRedis.existingSecret` | `""` | With `valkey.enabled=false`: a Secret holding the full `REDIS_URL` |
| `settings` | `{}` | More Kener settings as environment variables |
| `ingress.*` | off | Kener has no TLS listener: terminate TLS here and set `origin` to the https URL |

Kener runs one replica (SQLite on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kener \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

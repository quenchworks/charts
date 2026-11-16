# Quenchworks Yopass

Hardened [Yopass](https://github.com/jhaals/yopass): share passwords and other secrets through one-time links.
The browser encrypts each secret with OpenPGP before upload, and the server keeps only the ciphertext in
Memcached or Redis until it expires or is read. The image holds yopass-server, the yopass CLI and the web UI,
all built from source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build,
cosign-signed and pinned by digest.

Features behind a Yopass business license key (OIDC, theming, audit log, read receipts, webhooks) stay off
without one.

## Install

```bash
helm install secrets oci://ghcr.io/quenchworks/charts/yopass --set settings.PUBLIC_URL=https://secrets.example.com
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `store.type` | `memcached` | `memcached` or `redis` |
| `memcached.enabled` | `true` | Run the bundled QuenchWorks memcached chart |
| `store.memcached` | `""` | Your own Memcached (`host:port`) instead of the bundled one |
| `store.redisURL` | `""` | `redis://host:6379/0` for `store.type=redis`; a URL with a password goes in `extraEnvVarsSecret` (key `REDIS`) |
| `settings` | `{}` | yopass-server flags as environment variables, e.g. `PUBLIC_URL`, `FORCE_ONETIME_SECRETS`, `MAX_LENGTH`, `DISABLE_UPLOAD`, `TRUSTED_PROXIES` |
| `tls.enabled` | `false` | Native TLS on the same port (existingSecret, cert-manager or a Helm-generated CA) |
| `replicaCount` | `1` | The server is stateless; scale it out freely |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/yopass \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

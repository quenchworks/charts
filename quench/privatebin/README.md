# Quenchworks PrivateBin

Hardened [PrivateBin](https://github.com/PrivateBin/PrivateBin), a minimalist pastebin where the
server has zero knowledge of the data: pastes are encrypted and decrypted in the browser with
AES-256-GCM, with expiry, burn-after-reading, password protection and discussions. The image runs
the release tree on Wolfi php-fpm behind QuenchWorks' from-source nginx, as uid 1001; it is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install paste oci://ghcr.io/quenchworks/charts/privatebin
```

Browsers only run the encryption in a secure context, so serve it over HTTPS (an ingress with
TLS) for anything but localhost.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `config` | `""` | Your `conf.php` (INI), mounted over the image's; keep `dir = "/srv/data"` |
| `settings` | `{}` | More environment variables for php-fpm |
| `persistence.size` | `1Gi` | The paste store (`/srv/data`) |

The default configuration is upstream's sample (10 MiB pastes, one post per 10 seconds per
client, discussions on). Any key left out of `config` keeps its default.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/privatebin \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

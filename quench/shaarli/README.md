# Quenchworks Shaarli

Hardened [Shaarli](https://github.com/shaarli/Shaarli): a personal, minimalist bookmark manager and link
sharing service with tags, a daily digest, RSS/Atom feeds and a REST API, stored in flat files. The image
runs the release on Wolfi php-8.5-fpm and QuenchWorks' nginx, which serves only the front controller and
static assets; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install links oci://ghcr.io/quenchworks/charts/shaarli --set title="My links"
kubectl get secret links-shaarli -o jsonpath='{.data.password}' | base64 -d   # log in as admin
```

The account is written on the first start, so the install form never shows.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `user.login`, `user.password` | `admin`, generated | The account (used once, on the first start) |
| `apiSecret` | generated | The REST API secret (HS512 tokens) |
| `title`, `timezone` | `Shared Bookmarks`, `UTC` | Written into the first config |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `1Gi` | data/ (config and bookmarks), cache/, pagecache/ |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/shaarli \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

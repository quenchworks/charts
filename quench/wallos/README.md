# Quenchworks Wallos

Hardened [Wallos](https://github.com/ellite/Wallos): a self-hosted subscription and recurring-cost tracker with
multiple currencies, notifications (email, Discord, Telegram, ntfy, webhooks and more), statistics and TOTP 2FA,
on SQLite. The image runs php-fpm behind QuenchWorks' nginx with upstream's schedule under supercronic, as uid
1001 on a read-only root filesystem; it is CVE-gated at build, cosign-signed and pinned by digest.

The chart registers the first account (the admin) on the first start, so web registration is never left open.

## Install

```bash
helm install wallos oci://ghcr.io/quenchworks/charts/wallos --set admin.email=you@example.com --set tls.enabled=true
kubectl get secret wallos -o jsonpath='{.data.admin-password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email` | `admin`, `admin@example.com` | The first account |
| `admin.password` | generated | Stored in the Secret `<fullname>` (`admin-password`) |
| `admin.currency`, `admin.language` | `EUR`, `en` | Main currency code and language of the first account |
| `persistence.size` | `1Gi` | SQLite database, uploaded logos and restore staging (`/var/lib/wallos`) |
| `tls.enabled` | `false` | Native TLS on the same port (existingSecret, cert-manager or a Helm-generated CA) |
| `extraEnvVars` | `[]` | Wallos settings from the environment, e.g. `OIDC_*`, `SSRF_ALLOWLIST` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/wallos \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

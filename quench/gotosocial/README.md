# Quenchworks GoToSocial

Hardened [GoToSocial](https://gotosocial.org), a lightweight ActivityPub server for the fediverse: it
federates with Mastodon and others and speaks the Mastodon client API, so existing apps work. The image
is built from source (pure Go, OpenTelemetry left out with upstream's `nootel` tag); it runs as uid 1001
and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install social oci://ghcr.io/quenchworks/charts/gotosocial --set host=social.example.com
kubectl get secret social-gotosocial -o jsonpath='{.data.password}' | base64 -d   # user admin
```

Put it behind an ingress that serves `https://social.example.com`. `host` cannot change once the instance
has federated. The admin is created after the first start (GoToSocial's CLI needs the instance
application the first start creates) and its password is reset from the Secret on every start.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `host` | required | The instance's domain |
| `accountDomain` | `""` | user@domain handles on another host |
| `admin.username`, `admin.email` | `admin`, `admin@example.com` | The admin account |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `registrationOpen` | `false` | Let anyone request an account (an admin approves) |
| `trustedProxies` | `[]` | Proxies whose `X-Forwarded-For` to trust |
| `settings` | `{}` | More `GTS_*` settings |
| `persistence.size` | `20Gi` | SQLite and media |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gotosocial \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

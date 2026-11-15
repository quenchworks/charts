# Quenchworks Mercure

Hardened [Mercure](https://github.com/dunglas/mercure), a real-time push hub: your app publishes
updates with an HTTP POST and browsers or apps receive them over server-sent events, with private
updates for authorised subscribers. The image is Caddy with the Mercure module built from source; it runs
as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install hub oci://ghcr.io/quenchworks/charts/mercure --set trustedIssuers={https://app.example.com}
kubectl get secret hub-mercure -o jsonpath='{.data.publisher-key}' | base64 -d
```

## Tokens (Mercure 1.1, modern mode)

Mercure 1.1 checks access tokens the RFC 9068 way. A publisher token is an HS256 JWT signed with the
publisher key, with:

- header `"typ": "at+jwt"`
- `iss`: one of `trustedIssuers`
- `aud`: the hub URL, `https://<host>/.well-known/mercure`
- `exp`
- `"authorization_details": [{"type": "https://mercure.rocks/authorization-detail", "actions": ["publish"], "topics": [{"match": "https://example.com/books/1"}]}]`

Subscribers use `GET /.well-known/mercure?match=<topic>` (with a subscriber token for private updates, or
none for public ones when `anonymous` is on).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `trustedIssuers` | required | The `iss` values accepted in tokens |
| `jwt.existingSecret` | `""` | A Secret with `publisher-key` and `subscriber-key` instead of generated ones |
| `anonymous` | `false` | Public subscriptions without a token |
| `corsOrigins` | `[]` | Browser origins allowed to subscribe |
| `extraDirectives` | `""` | More lines for the mercure block |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

The default local transport keeps history in memory, so the chart runs one replica.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mercure \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

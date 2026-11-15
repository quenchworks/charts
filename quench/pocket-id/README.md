# Quenchworks Pocket ID

Hardened [Pocket ID](https://github.com/pocket-id/pocket-id), a simple OIDC provider whose users
sign in with passkeys only, with an admin UI and API. The image is one CGO-free Go binary built
from source with the SvelteKit frontend embedded, runs as uid 1001 and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install id oci://ghcr.io/quenchworks/charts/pocket-id --set appUrl=https://id.example.com
kubectl port-forward svc/id-pocket-id 1411
```

Open `/setup` and register the first admin's passkey. The setup page is open to whoever reaches
it first: the chart ships a ClusterIP Service, so finish setup over the port-forward before you
put an ingress in front of it.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `appUrl` | `http(s)://localhost:1411` | `APP_URL`: issuer in every token and the WebAuthn RP ID (a domain); set before the first sign-in |
| `encryptionKey.value` | generated | `ENCRYPTION_KEY` for the stored signing keys, kept in the Secret `<fullname>` |
| `database.existingSecret` | `""` (SQLite) | Secret holding a PostgreSQL `DB_CONNECTION_STRING` (key `database.urlKey`) |
| `tls.enabled` | `false` | Native TLS: HTTPS instead of HTTP on the one port, certificate from a Secret, cert-manager or a generated CA |
| `settings` | `{}` | More Pocket ID env (`TRUST_PROXY`, `STATIC_API_KEY`, SMTP, ...) |

One replica: the data volume is ReadWriteOnce and the Deployment uses Recreate. Back up the
encryption key Secret; without it the stored signing keys are unreadable.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pocket-id \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

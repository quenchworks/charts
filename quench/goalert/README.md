# Quenchworks goalert

[GoAlert](https://goalert.me) 0.35.0, on-call scheduling with automated escalations and
notifications (SMS and voice through Twilio, email, Slack, webhooks), from the QuenchWorks image:
built from source with the web UI embedded, nonroot, CVE-gated at build, pinned by digest and
cosign-signed. Its database is a bundled PostgreSQL (or your own), and a post-install Job creates
the first administrator.

## Install

```bash
helm install goalert oci://ghcr.io/quenchworks/charts/goalert -n goalert --create-namespace \
  --set publicUrl=https://goalert.example.com
kubectl -n goalert get secret goalert -o jsonpath='{.data.admin-password}' | base64 -d
```

Sign in as `admin` with that password. GoAlert checks the sign-in referer against `publicUrl`,
so set it to the address people open (behind your ingress), or sign in through that address.

## Values

| Key | Default | Notes |
|---|---|---|
| `publicUrl` | `http://<fullname>:8081` | GOALERT_PUBLIC_URL: links, redirects and the sign-in referer check |
| `admin.create`, `admin.username` | `true`, `admin` | first administrator, created once at install |
| `dataEncryptionKey.value` / `.existingSecret` | generated, kept | encrypts signing keys and provider credentials |
| `postgresql.enabled` | `true` | bundled PostgreSQL; `false` uses `externalDatabase.*` |
| `externalDatabase.sslMode` | `disable` | sslmode in the connection URL |
| `tls.enabled` | `false` | HTTPS on 8443 (Service `service.httpsPort`) beside HTTP on 8081 |

## Notes

- Keep the data-encryption key: without it the data GoAlert encrypted cannot be read. The
  generated key stays in the Secret `<fullname>` across upgrades.
- Notification providers (Twilio, SMTP, Slack, webhooks) are configured in the UI under Admin.
- An external database password with URL-reserved characters must be percent-encoded in its
  Secret: the chart puts it into the connection URL.
- `admin.*` only applies to the first install; manage users in GoAlert afterwards.

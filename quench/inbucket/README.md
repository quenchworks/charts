# Quenchworks Inbucket

Hardened [Inbucket](https://github.com/inbucket/inbucket), a disposable-email testing server: point
the apps under test at its SMTP port and every message, for any address, lands in a mailbox you can
read in the web UI, over the REST API or with POP3. Nothing is delivered onward. The image is one
static Go binary built from source with upstream's web UI; it runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install mail oci://ghcr.io/quenchworks/charts/inbucket
```

Apps send to `mail-inbucket.<namespace>.svc:2500`; the UI is on port 9000. Inbucket has no login,
so keep the Service inside the cluster or put an authenticating ingress in front of the UI.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `retention`, `mailboxMessageCap` | `72h`, `300` | How long mail is kept and how many messages a mailbox holds |
| `pop3.enabled` | `true` | POP3 on 1100; off binds it to the pod's loopback |
| `service.port`, `service.smtpPort`, `service.pop3Port` | `9000`, `2500`, `1100` | Service ports |
| `settings` | `{}` | More `INBUCKET_*` env (`INBUCKET_SMTP_REJECTDOMAINS`, ...) |
| `persistence.size` | `1Gi` | The mail store (`/storage`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/inbucket \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

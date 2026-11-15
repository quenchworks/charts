# Quenchworks Maddy

Hardened [Maddy](https://github.com/foxcpp/maddy), an all-in-one mail server: SMTP for incoming mail
(MX), submission for your users, IMAP, and DKIM, SPF, DMARC and MTA-STS checks, in one binary. The image is
built from source (pure Go); it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by
digest.

## Install

```bash
helm install mail oci://ghcr.io/quenchworks/charts/maddy \
  --set hostname=mx.example.com --set primaryDomain=example.com \
  --set tls.enabled=true --set service.type=LoadBalancer
kubectl exec deploy/mail-maddy -- maddy -config /data/maddy.conf creds create you@example.com
kubectl exec deploy/mail-maddy -- maddy -config /data/maddy.conf imap-acct create you@example.com
```

The pod listens on ports above 1024 (nonroot); the Service publishes 25, 587, 143 and, with TLS, 993.
Give `tls` a real certificate for `hostname` (cert-manager or an existing Secret) before you expose it, and
set the MX, SPF and DKIM DNS records for your domain as upstream's docs describe.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `hostname`, `primaryDomain` | required | The MX host name and the mail domain |
| `extraDomains` | `[]` | More domains delivered to local mailboxes |
| `extraConfig` | `""` | Appended to maddy.conf (DKIM signing, routing, more listeners) |
| `tls.enabled` | `false` | STARTTLS on all listeners and IMAPS on 993; off accepts plain-text logins |
| `persistence.size` | `10Gi` | Credentials, mailboxes and the queue |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/maddy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

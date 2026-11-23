# mox

[mox](https://www.xmox.nl), a modern full-featured mail server in one Go binary: SMTP with SPF, DKIM, DMARC and
MTA-STS, IMAP4, webmail, and admin and account web UIs. The image is built from source by QuenchWorks, runs as uid 1001
(a small patch lets mox start unprivileged instead of starting as root and dropping privileges), CVE-gated, signed with
cosign and pinned by digest.

## Install

```sh
helm install mail oci://ghcr.io/quenchworks/charts/mox --set hostname=mail.example.com --set domain=example.com \
  --set 'accounts[0].name=me' --set 'accounts[0].addresses[0]=me@example.com' \
  --set tls.enabled=true --set service.type=LoadBalancer
kubectl exec -i deploy/mail-mox -- mox setaccountpassword me
```

The listeners use unprivileged container ports (2525, 2587, 4465, 1143, 9993, 8080); the Service maps the standard
ports to them. Real mail delivery needs DNS (MX, SPF, DKIM, DMARC) and port 25 reachable from the internet.

## Configuration

`config/mox.conf` is rendered from values and rewritten on every start. `config/domains.conf` (domains, accounts) is
written on the first start only; the admin web UI owns it afterwards (add domains, generate DKIM keys, aliases).

| Key | Default | Meaning |
|---|---|---|
| `hostname`, `domain` | `mail.example.com`, `example.com` | The server's host name and its first mail domain. |
| `accounts` | `admin` | Accounts created on the first start; the first one receives postmaster mail. |
| `admin.password` | generated | The web admin password (Secret key `admin-password`). |
| `tls.enabled` | `false` | STARTTLS, submissions (465) and IMAPS (993) from the PEM pair (existing Secret, cert-manager, or a Helm-made CA). |
| `service.type` | `ClusterIP` | `LoadBalancer` for a real mail server; `externalTrafficPolicy: Local` keeps client IPs. |
| `forwardedHeaders` | `false` | Trust X-Forwarded-* on the web listener (behind an Ingress). |
| `persistence.*` | 10Gi RWO | Configuration and data. One replica. |

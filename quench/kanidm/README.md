# Quenchworks Kanidm

Hardened [Kanidm](https://github.com/kanidm/kanidm), an identity management server: people and groups,
OAuth2 and OpenID Connect for your apps, passkeys, read-only LDAPS and a web UI. The image is kanidmd
built from source in Rust with its crate list embedded; it runs as uid 1001 and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install idm oci://ghcr.io/quenchworks/charts/kanidm --set domain=idm.example.com
kubectl exec deploy/idm-kanidm -- kanidmd recover-account admin
kubectl exec deploy/idm-kanidm -- kanidmd recover-account idm_admin
```

Each `recover-account` run prints a new password. `admin` manages the server, `idm_admin` manages
people and groups. Sign in at `https://<domain>/ui`.

**`domain` cannot change after the first start**: it is part of every account, passkey and OAuth2
client. Pick the name clients will use.

## TLS

kanidmd always serves TLS, so `tls.enabled` stays on. The certificate comes from `tls.existingSecret`,
a cert-manager Certificate (`tls.certManager`), or by default a Helm-made CA and certificate, which
browsers warn about until you trust its `ca.crt`. For production, give it a certificate for `domain`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | required | The DNS name clients use (fixed after the first start) |
| `origin` | `https://<domain>` | The public URL |
| `ldap.enabled` | `false` | Read-only LDAPS on 3636 (Service port 636) |
| `backup.enabled`, `backup.schedule`, `backup.versions` | `true`, daily 22:00, 7 | Online backups to `/data/backups` on the same volume |
| `persistence.size` | `10Gi` | The volume: database and backups |
| `tls.*` | Helm-made CA | Where the certificate comes from |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kanidm \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

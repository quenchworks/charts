# Quenchworks ezBookkeeping

Hardened [ezBookkeeping](https://github.com/mayswind/ezbookkeeping), self-hosted personal finance and
bookkeeping: accounts, transactions, budgets, multi-currency, reports and import/export, with a web UI
that installs as a phone app (PWA). The image is built from source with its Vue frontend; it runs as uid
1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install money oci://ghcr.io/quenchworks/charts/ezbookkeeping
kubectl port-forward svc/money-ezbookkeeping 8080:8080
```

Open http://localhost:8080 and create your account. ezBookkeeping has no admin role: every user has their
own books. Once your accounts exist, close sign-ups with `--set registration.enabled=false`; you can still
add users with `kubectl exec deploy/money-ezbookkeeping -- /ezbookkeeping/ezbookkeeping userdata user-add ...`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `registration.enabled` | `true` | Open sign-ups in the web UI |
| `domain` | `""` | The host name used in links (EBK_SERVER_DOMAIN) |
| `existingSecret` | `""` | A Secret with `secret-key` (signs sessions) instead of a generated one |
| `persistence.size` | `5Gi` | The SQLite database and uploads |
| `settings` | `{}` | More `EBK_<SECTION>_<KEY>` variables, e.g. PostgreSQL instead of SQLite |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ezbookkeeping \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

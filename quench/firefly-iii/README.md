# Quenchworks Firefly III

Hardened [Firefly III](https://github.com/firefly-iii/firefly-iii): a self-hosted personal finance
manager with accounts, budgets, categories, rules, recurring transactions, reports and a REST API. The
image runs upstream's release on Wolfi php-8.5-fpm and QuenchWorks' nginx, with Laravel and Symfony
raised to their fixed patch releases; it runs as uid 1001 and is CVE-gated at build, cosign-signed and
pinned by digest.

## Install

```bash
helm install money oci://ghcr.io/quenchworks/charts/firefly-iii --set appURL=https://money.example.com
kubectl port-forward svc/money-firefly-iii 8080:8080   # open http://127.0.0.1:8080/register
```

Create the first account on `/register` right away: Firefly III then closes registration. The pod
migrates the database on every start, so the first start takes a minute.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `appKey.value`, `appKey.existingSecret` | generated | APP_KEY (32 characters), kept across upgrades. Back it up with the data |
| `appURL` | `""` | The public URL (APP_URL) |
| `trustedProxies` | `""` | TRUSTED_PROXIES, e.g. `"**"` behind an ingress |
| `settings` | `{}` | More environment variables: TZ, mail, `DB_CONNECTION` and `DB_HOST` for PostgreSQL or MySQL |
| `extraEnvVarsSecret` | `""` | A Secret of variables, e.g. `DB_PASSWORD` |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `5Gi` | Storage: SQLite database, uploads, OAuth keys, logs |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/firefly-iii \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

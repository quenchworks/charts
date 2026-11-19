# Quenchworks Kutt

Hardened [Kutt](https://github.com/thedevs-network/kutt), a URL shortener with custom domains, link stats,
password-protected and expiring links, an API and an admin panel. The image is built from source on Wolfi Node 24
with better-sqlite3 compiled locally; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by
digest.

## Install

```bash
helm install links oci://ghcr.io/quenchworks/charts/kutt --set domain=s.example.com --set admin.email=you@example.com
kubectl get secret links-kutt -o jsonpath='{.data.admin-password}' | base64 -d
```

Until its create-admin form is posted, Kutt lets anyone who reaches it create the admin account. A post-install
Job claims it right away with `admin.email` and the generated password; Kutt refuses the form once any user exists,
so upgrades leave accounts alone. The image runs the database migrations at start and refuses to start without
`JWT_SECRET`, which the chart generates and keeps across upgrades.

Point `domain` at the Service through your ingress or load balancer: Kutt builds short links on that host and
resolves them by it.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | `""` (required) | The host short links are served on (`DEFAULT_DOMAIN`) |
| `admin.email` | `""` (required) | The admin account the bootstrap Job creates |
| `allowRegistration` | `false` | Let visitors sign up (needs mail settings) |
| `allowAnonymousLinks` | `false` | Let visitors shorten links without signing in |
| `existingSecret` | `""` | A Secret with `jwt-secret` and `admin-password` |
| `persistence.size` | `1Gi` | The SQLite database |
| `settings` | `{}` | More environment variables: `MAIL_*`, `OIDC_*`, `REDIS_*`, or `DB_CLIENT=pg` with `DB_*` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kutt \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

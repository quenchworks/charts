# Quenchworks Healthchecks

Hardened [Healthchecks](https://github.com/healthchecks/healthchecks), cron job and heartbeat
monitoring: every job pings a URL when it runs, and a ping that does not arrive on schedule raises
an alert by email, Slack, webhooks and the other integrations in its web UI. The image is the
Django app in a venv on Wolfi Python, with pycurl and psycopg compiled against Wolfi's libcurl and
libpq; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install hc oci://ghcr.io/quenchworks/charts/healthchecks --set siteRoot=https://hc.example.com
kubectl get secret hc-healthchecks -o jsonpath='{.data.password}' | base64 -d
```

An init container runs the migrations and creates `admin.email` as a superuser with the generated
password while that email has no account. Self sign-up is off (`REGISTRATION_OPEN: "False"`).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `siteRoot` | `http://localhost:8000` | `SITE_ROOT`: ping URLs, links in alerts, and the host Django accepts |
| `admin.create`, `admin.email` | `true`, `admin@example.com` | The superuser the init container creates |
| `settings` | sign-up off, 2 gunicorn workers | More env (`EMAIL_HOST`, `DB: postgres`, integrations) |
| `persistence.size` | `1Gi` | SQLite data volume (`/data/hc.sqlite`) |

Django's `SECRET_KEY` is generated into the Secret `<fullname>` and kept across upgrades. With
PostgreSQL (`settings.DB: postgres`, `DB_HOST`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` through
`extraEnvVars`) the volume is not needed.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/healthchecks \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

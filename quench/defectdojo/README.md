# Quenchworks DefectDojo

Hardened [DefectDojo](https://github.com/DefectDojo/django-DefectDojo): vulnerability management and ASPM. It
imports findings from more than 200 scanners (ZAP, Nuclei, Trivy, Semgrep and others), deduplicates them, and tracks
them per product and engagement through remediation, with an API for CI pipelines. The image builds DefectDojo from
the release tag in a Python 3.14 venv on Wolfi, with the components build and collected static files, runs as uid
1001 on a read-only root filesystem, and is CVE-gated at build, cosign-signed and pinned by digest.

One image runs every role. The web pod runs the initializer (migrations, the admin user, fixtures) as an init
container, then uWSGI, whose HTTP router serves the app and, through whitenoise, its static files, so there is no
separate nginx. Celery worker and beat run as their own Deployments. The chart bundles the QuenchWorks PostgreSQL
and Valkey, generates Django's secret key, the credential AES key and the admin password once, and can serve native
TLS from uWSGI.

## Install

```bash
helm install dojo oci://ghcr.io/quenchworks/charts/defectdojo -n dojo --create-namespace \
  --set siteURL=https://dojo.example.com --set allowedHosts={dojo.example.com}
```

## Configuration

| Value | Default | Notes |
|---|---|---|
| `siteURL` | `""` | Public URL, used in notification links |
| `allowedHosts` | `[]` | Host names besides the Service's own (an Ingress host) |
| `admin.password` | `""` | Generated when empty |
| `celery.worker.replicaCount` | `1` | Import and deduplication throughput |
| `postgresql.enabled` / `valkey.enabled` | `true` | Or `externalDatabase.*` / `externalBroker.*` |
| `settings` | `{}` | More `DD_*` settings (SSO, email, ...) |
| `tls.enabled` | `false` | uWSGI serves HTTPS on 8443 behind the same Service port |

The web Deployment runs one replica with the Recreate strategy: its initializer must not run twice at once.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/defectdojo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

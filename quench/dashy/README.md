# Quenchworks Dashy

Hardened [Dashy](https://github.com/Lissy93/dashy), a self-hosted start page and dashboard with widgets, status
checks, themes and multiple pages, configured in YAML and editable in the UI. The image is built from source on
Wolfi Node 24; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install home oci://ghcr.io/quenchworks/charts/dashy
kubectl get secret home-dashy -o jsonpath='{.data.password}' | base64 -d   # user "admin"
```

Basic auth is on by default. Without auth, Dashy's config editor lets anyone who reaches it rewrite `conf.yml`; turn
`auth.enabled` off only behind an authenticating proxy, or configure OIDC or Keycloak in `conf.yml`.

`config` seeds the first `conf.yml` on the volume. After that the volume wins: edits made in the UI are kept, and
changing `config` does not overwrite them (delete `conf.yml` on the volume to re-seed).

## TLS

Set `tls.existingSecret` to a `kubernetes.io/tls` Secret: Dashy serves HTTPS on 8443 (`service.httpsPort`) and
redirects plain HTTP to it.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled` | `true` | Basic auth for the app and the config editor |
| `auth.username` | `admin` | The basic-auth user |
| `auth.existingSecret` | `""` | A Secret with `password` instead of a generated one |
| `config` | a starter page | The first `conf.yml` |
| `tls.existingSecret` | `""` | Serve HTTPS with this certificate |
| `persistence.size` | `512Mi` | `conf.yml`, other pages and config backups |
| `settings` | `{}` | More environment variables |

Ping-mode status checks are off: the image has no `ping` with raw-socket privileges. HTTP status checks work.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dashy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

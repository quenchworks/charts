# Quenchworks Etherpad

Hardened [Etherpad](https://github.com/ether/etherpad): real-time collaborative document editing with plugins, an
HTTP API and an admin UI. The image builds Etherpad from the release tag (admin UI with the full workspace, then a
production install of the server with patched dependency floors) on Wolfi Node 24. It runs as uid 1001 on a
read-only root filesystem, keeps the minified cache and the API and session key files on a volume, and is
CVE-gated at build, cosign-signed and pinned by digest. The image ships no pnpm, so plugins are installed by
rebuilding the image, not from the admin UI.

The chart runs on the bundled QuenchWorks PostgreSQL (pads live there), generates the /admin password and the two
built-in SSO client secrets once (upstream defaults them to `admin` / `user`), and can serve native TLS on 9001.

## Install

```bash
helm install pad oci://ghcr.io/quenchworks/charts/etherpad --set publicURL=https://pad.example.com
```

The admin UI is `/admin`, user `admin`; read the password from the chart Secret (see the install notes).

## Configuration

| Value | Default | Notes |
|---|---|---|
| `publicURL` | `""` | Public URL; also the built-in SSO issuer and redirect URIs |
| `authenticationMethod` | `sso` | HTTP API auth: `sso` (OAuth2 from Etherpad's OIDC provider) or `apikey` |
| `adminPassword` | `""` | Generated when empty |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` with a Secret holding the password |
| `settings` | `{}` | More settings as environment variables (`DEFAULT_PAD_TEXT`, `REQUIRE_AUTHENTICATION`, ...) |
| `tls.enabled` | `false` | HTTPS on 9001 from `tls.existingSecret`, cert-manager, or a Helm-made CA |
| `trustProxy` | `false` | Set true behind an Ingress that sets X-Forwarded-* |

Etherpad runs one replica (the key files on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/etherpad \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

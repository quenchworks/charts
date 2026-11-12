# Quenchworks Actual

Hardened [Actual](https://github.com/actualbudget/actual), local-first personal budgeting, CVE-gated,
cosign-signed and pinned by digest. The image is the sync server and its web client from npm on
Node 24, with the native modules (better-sqlite3, argon2, bcrypt) compiled from source, on a
nonroot Wolfi base.

## Install

```bash
helm install actual oci://ghcr.io/quenchworks/charts/actual --set tls.enabled=true
kubectl port-forward svc/actual 5006
```

Open `https://localhost:5006` and set the server password on the first visit. Until then anyone
who reaches the Service can set it, so do it before exposing the Service.

The web client needs a secure context (HTTPS) except on localhost: enable `tls` (Actual serves
HTTPS itself) or terminate TLS in an Ingress in front.

## Storage

`/data` holds the server database and every synced budget file, on a PersistentVolumeClaim. One
replica with `Recreate`.

## Settings

`settings` sets `ACTUAL_*` environment variables, for example OpenID login:

```yaml
settings:
  ACTUAL_LOGIN_METHOD: openid
  ACTUAL_OPENID_DISCOVERY_URL: https://id.example.com/.well-known/openid-configuration
  ACTUAL_OPENID_CLIENT_ID: actual
extraEnvVarsSecret: actual-oidc   # ACTUAL_OPENID_CLIENT_SECRET
```

## TLS

With `tls.enabled` Actual serves HTTPS on its one port (5006) from a certificate in
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in the
Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/actual \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `settings` | `{}` | `ACTUAL_*` environment variables |
| `persistence.size` | `2Gi` | The `/data` volume |
| `service.port` | `5006` | Service port (HTTP, or HTTPS with `tls.enabled`) |
| `tls.enabled` | `false` | Actual serves HTTPS itself |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |

# Quenchworks Homebox

Hardened [Homebox](https://github.com/sysadminsmedia/homebox), a home inventory and asset tracker,
CVE-gated, cosign-signed and pinned by digest. The image is built from source (the Nuxt web UI
embedded in the Go backend) on a nonroot Wolfi base.

## Install

```bash
helm install homebox oci://ghcr.io/quenchworks/charts/homebox
kubectl port-forward svc/homebox 7745
```

Open `http://localhost:7745` and register the first user. Then close registration:

```yaml
settings:
  HBOX_OPTIONS_ALLOW_REGISTRATION: "false"
```

## Storage and database

`/data` holds the SQLite database and attachments, on a PersistentVolumeClaim. One replica with
`Recreate`. For PostgreSQL, set `HBOX_DATABASE_DRIVER: postgres` and the `HBOX_DATABASE_*`
settings, with the password from a Secret via `extraEnvVarsSecret`; attachments stay on the volume.

## API key pepper

Homebox 0.27 refuses to start without `HBOX_AUTH_API_KEY_PEPPER` (at least 32 bytes). The chart
generates one into the Secret `<fullname>` (`api-key-pepper`) and keeps it across upgrades:
rotating it invalidates every API key.

## Image formats

AVIF and WebP thumbnails decode through the bundled WASM decoders; the image carries no native
image libraries (libheif, libavif, libwebp), so HEIC thumbnails are not generated.

## TLS

Homebox serves plain HTTP. With `tls.enabled` a caddy sidecar terminates HTTPS on 8443 (Service
port `service.httpsPort`) and proxies to Homebox over localhost. The certificate comes from
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in the
Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/homebox \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `settings` | registration on, analytics off | `HBOX_*` environment variables |
| `apiKeyPepper.value` / `existingSecret` | generated | `HBOX_AUTH_API_KEY_PEPPER` |
| `persistence.size` | `5Gi` | The `/data` volume |
| `service.port` | `7745` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

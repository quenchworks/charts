# Quenchworks Vaultwarden

Hardened [Vaultwarden](https://github.com/dani-garcia/vaultwarden), a Bitwarden-compatible password
manager server for the official Bitwarden clients, CVE-gated, cosign-signed and pinned by digest. The
image is built from source (Rust, `cargo auditable`) with the web vault from
[bw_web_builds](https://github.com/dani-garcia/bw_web_builds), on a nonroot Wolfi base.

## Install

```bash
helm install vaultwarden oci://ghcr.io/quenchworks/charts/vaultwarden --set tls.enabled=true
kubectl port-forward svc/vaultwarden 8080
```

Open `https://localhost:8080`, create an account, then set `settings.DOMAIN` to the URL the
clients use and close sign-ups:

```yaml
settings:
  DOMAIN: https://vault.example.com
  SIGNUPS_ALLOWED: "false"
```

Bitwarden clients and the web vault need HTTPS. Either enable `tls` here (Vaultwarden serves HTTPS
itself) or terminate TLS in an Ingress in front.

## Storage and database

`/data` holds SQLite, the server's RSA signing keys, attachments and sends, on a
PersistentVolumeClaim; keep it. One replica with `Recreate`. For PostgreSQL or MySQL set
`DATABASE_URL` from a Secret via `extraEnvVarsSecret`; the keys and attachments stay on the volume.

## Admin panel

`admin.enabled: true` turns on `/admin` with a token generated into the Secret `<fullname>`
(`admin-token`) and kept across upgrades, or bring your own with `admin.token` /
`admin.existingSecret`.

## TLS

With `tls.enabled` Vaultwarden serves HTTPS on its one port (8080) from a certificate in
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in the
Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vaultwarden \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `settings` | sign-ups and invitations on, hints off | Vaultwarden environment variables |
| `admin.enabled` | `false` | The `/admin` panel |
| `admin.token` / `admin.existingSecret` | generated | `ADMIN_TOKEN` |
| `persistence.size` | `2Gi` | The `/data` volume |
| `service.port` | `8080` | Service port (HTTP, or HTTPS with `tls.enabled`) |
| `tls.enabled` | `false` | Vaultwarden serves HTTPS itself |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |

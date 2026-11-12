# Quenchworks Umami

Hardened [Umami](https://github.com/umami-software/umami), privacy-focused web
analytics without cookies, CVE-gated, cosign-signed and pinned by digest. The
image is built from source (Next.js standalone, Prisma 7) on a nonroot Wolfi base.

## Install

```bash
helm install umami oci://ghcr.io/quenchworks/charts/umami
kubectl port-forward svc/umami-umami 3000
```

Log in as `admin` / `umami` and change the password right away. Then add a
website and put its tracker on your pages:

```html
<script defer src="https://umami.example.com/script.js" data-website-id="<id>"></script>
```

Each pod migrates the database (`prisma migrate deploy`) before it serves; the
startup probe allows 10 minutes. Umami keeps no local state, so `replicaCount`
can go above 1.

## Database

By default Umami uses the bundled PostgreSQL subchart. For an external PostgreSQL:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.internal
  database: umami
  username: umami
  existingSecret: umami-db
  existingSecretPasswordKey: password
  sslMode: require
```

The chart builds `DATABASE_URL` from these, with the password inserted as is:
keep it URL-safe (letters, digits, `-`, `_`, `.`, `~`). An init container waits
until the database accepts connections.

## App secret

`APP_SECRET` signs login tokens and share links. The chart generates one and
keeps it across upgrades in the Secret `<fullname>` (`app-secret`). Set
`appSecret.value` or `appSecret.existingSecret` to bring your own; changing it
logs everyone out.

## TLS

Umami's server speaks plain HTTP. With `tls.enabled` a caddy sidecar terminates
HTTPS on 3443 (Service port `service.httpsPort`) and proxies to it over
localhost; the probes keep HTTP on 3000. The certificate comes from
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated
CA + certificate (`ca.crt` in the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/umami \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `replicaCount` | `1` | Stateless; scale out freely |
| `appSecret.value` / `existingSecret` | generated | `APP_SECRET` |
| `settings` | `DISABLE_TELEMETRY: "1"` | More [environment variables](https://umami.is/docs/environment-variables), e.g. `TRACKER_SCRIPT_NAME`, `BASE_PATH` |
| `postgresql.enabled` | `true` | Bundled PostgreSQL |
| `externalDatabase.*` | | External PostgreSQL when the subchart is off |
| `waitForDatabase.enabled` | `true` | Init container that waits for PostgreSQL |
| `resources` | 256Mi / 1Gi memory | |
| `service.port` | `3000` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port (to the sidecar's 3443), only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 3443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |
| `ingress.enabled` | `false` | Ingress |

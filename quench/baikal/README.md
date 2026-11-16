# Quenchworks Baikal

Hardened [Baikal](https://github.com/sabre-io/Baikal): a lightweight CalDAV and CardDAV server on sabre/dav
with a web admin, on SQLite. The image runs the release on Wolfi php-8.5-fpm and QuenchWorks' nginx; it runs
as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install dav oci://ghcr.io/quenchworks/charts/baikal --set davUser.username=alice
kubectl get secret dav-baikal -o jsonpath='{.data.dav-password}' | base64 -d   # alice's DAV password
```

The install wizard never shows: the chart writes the config, creates the database and, with
`davUser.username`, a first user with a default calendar and address book. Add more users in `/admin/`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `adminPassword` | generated | The /admin password (used once, on the first start) |
| `davUser.username`, `davUser.email`, `davUser.password` | none, generated password | An optional first DAV user |
| `davAuthType` | `Digest` | HTTP auth for clients: `Digest` or `Basic` (use Basic with TLS) |
| `timezone` | `UTC` | The server time zone |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `1Gi` | config/ and the SQLite database |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/baikal \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

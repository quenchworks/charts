# Quenchworks yarr

Hardened [yarr](https://github.com/nkanaev/yarr) (yet another rss reader), a self-hosted RSS and
Atom reader with a web UI and a Fever API for mobile clients, on SQLite. The image is one static Go
binary built from source with its Vue frontend embedded; it runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install news oci://ghcr.io/quenchworks/charts/yarr
kubectl get secret news-yarr -o jsonpath='{.data.password}' | base64 -d
```

The chart turns yarr's login on with a generated password for `auth.username`. Mobile apps that
speak the Fever API connect to `/fever/` with the same login.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled`, `auth.username` | `true`, `admin` | The login (`YARR_AUTH`); the password is generated and kept across upgrades |
| `auth.existingSecret` | `""` | A Secret whose key `auth` holds `username:password` |
| `basePath` | `""` | `YARR_BASE`, to serve under a sub-path behind an ingress |
| `persistence.size` | `1Gi` | SQLite data volume (`/data/yarr.db`) |
| `tls.enabled` | `false` | yarr serves HTTPS on port 7070 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/yarr \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

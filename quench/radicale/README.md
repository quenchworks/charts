# Quenchworks Radicale

Hardened [Radicale](https://radicale.org), a small CalDAV and CardDAV server: calendars, task lists and
contacts for phones (DAVx5, iOS), Thunderbird and other clients, stored as plain files. The image is
built from source into a venv on Wolfi Python 3.13 with Wolfi's bcrypt; it runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install dav oci://ghcr.io/quenchworks/charts/radicale --set tls.enabled=true
kubectl get secret dav-radicale -o jsonpath='{.data.password}' | base64 -d   # user admin
kubectl port-forward svc/dav-radicale 5232:5232
```

Open https://127.0.0.1:5232/ to create calendars and address books, then point clients at
`https://<host>:5232/admin/`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.username` | `admin` | The user (password generated into the Secret, bcrypt line in `htpasswd`) |
| `auth.existingSecret` | `""` | A Secret whose key `htpasswd` holds your own bcrypt lines (one per user) |
| `rights` | `owner_only` | Who sees which collections |
| `maxContentLength` | `100000000` | Largest request body in bytes |
| `extraConfig` | `""` | More INI sections appended to the config |
| `persistence.size` | `2Gi` | The collections (`/var/lib/radicale`) |
| `tls.enabled` | `false` | HTTPS on 5232 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/radicale \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

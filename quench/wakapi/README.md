# Quenchworks Wakapi

Hardened [Wakapi](https://github.com/muety/wakapi), a self-hosted, WakaTime-compatible backend for
coding statistics: point the WakaTime editor plugins at it and browse your stats in its web UI or
API. The image is one CGO-free Go binary built from source; it runs as uid 1001 and is CVE-gated
at build, cosign-signed and pinned by digest.

## Install

```bash
helm install stats oci://ghcr.io/quenchworks/charts/wakapi --set publicUrl=https://wakapi.example.com
kubectl get secret stats-wakapi -o jsonpath='{.data.password}' | base64 -d
```

Wakapi makes the first account that signs up the admin and has no setting to declare one, so a
setup Job (busybox `wget`) signs up `admin.username` with a generated password right after the
install and then the release gate proves the login. Self sign-up stays on for that Job; turn it off afterwards with
`settings.WAKAPI_ALLOW_SIGNUP: "false"`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `publicUrl` | `http://localhost:3000` | `WAKAPI_PUBLIC_URL`; an https URL also turns on secure cookies |
| `admin.create`, `admin.username`, `admin.email` | `true`, `admin`, `admin@example.com` | The admin the setup Job signs up |
| `settings` | `{}` | More `WAKAPI_*` env (signup, mail, PostgreSQL or MySQL) |
| `persistence.size` | `1Gi` | SQLite data volume |

The password salt is generated into the Secret `<fullname>` and kept across upgrades: changing it
would invalidate every stored password.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/wakapi \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

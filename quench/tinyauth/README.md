# Quenchworks Tinyauth

Hardened [Tinyauth](https://github.com/tinyauthapp/tinyauth), a lightweight login portal and
forward-auth server: put it in front of apps behind nginx, Traefik or Caddy and every request is
checked against a Tinyauth session first. Local users, TOTP, and OAuth/OIDC providers. The image is
one CGO-free Go binary built from source with the web UI (pnpm) embedded; it runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install auth oci://ghcr.io/quenchworks/charts/tinyauth --set appUrl=https://auth.example.com
kubectl get secret auth-tinyauth -o jsonpath='{.data.password}' | base64 -d
```

`appUrl` must be a dotted host: Tinyauth sets its session cookie on the parent domain
(`example.com`), so the apps it protects live on sibling hosts (`app.example.com`).

Protect an app with ingress-nginx:

```yaml
nginx.ingress.kubernetes.io/auth-url: http://auth-tinyauth.<namespace>.svc:3000/api/auth/nginx
nginx.ingress.kubernetes.io/auth-signin: https://auth.example.com/login
```

Traefik uses a ForwardAuth middleware on `/api/auth/traefik`, Caddy `forward_auth` on
`/api/auth/caddy`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `appUrl` | `http://auth.example.com` | `TINYAUTH_APPURL`; an https URL also turns on secure cookies |
| `admin.username`, `admin.password` | `admin`, generated | The admin; its bcrypt line goes into `TINYAUTH_AUTH_USERS` |
| `admin.existingSecret` | `""` | A Secret whose key `users` holds the whole `TINYAUTH_AUTH_USERS` value |
| `extraUsers` | `[]` | More `name:bcrypt-hash` users |
| `settings` | label provider and analytics off | More `TINYAUTH_*` env (OAuth, OIDC, LDAP, trusted proxies) |
| `persistence.size` | `1Gi` | SQLite session volume; without it a restart logs everyone out |

The generated password and its hash are kept across upgrades as a matching pair. The label
provider stays off because its Kubernetes mode reads ingress labels and needs RBAC this chart does
not grant.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tinyauth \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

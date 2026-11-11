# Quenchworks Vouch Proxy

Hardened [Vouch Proxy](https://github.com/vouch/vouch-proxy): single sign-on for nginx
`auth_request`. nginx asks Vouch at `/validate` whether each request carries a valid session;
Vouch logs users in through an OIDC or OAuth provider (Google, GitHub, Okta, Keycloak, Azure AD,
any OIDC issuer) and keeps the session in a signed JWT cookie. Apps with no login of their own can
then sit behind SSO.

The image is built from the upstream tag as one static Go binary, runs as nonroot uid 1001, is
CVE-gated (the build fails on any fixable CVE), and is cosign-signed and pinned by digest.

## Install

```bash
helm install sso oci://ghcr.io/quenchworks/charts/vouch-proxy \
  --set 'vouch.domains={example.com}' \
  --set oauth.clientId=vouch --set oauth.clientSecret=<secret> \
  --set oauth.authUrl=https://id.example.com/authorize \
  --set oauth.tokenUrl=https://id.example.com/token \
  --set oauth.userInfoUrl=https://id.example.com/userinfo \
  --set oauth.callbackUrl=https://vouch.example.com/auth
```

Then, on each protected ingress-nginx Ingress:

```yaml
nginx.ingress.kubernetes.io/auth-url: "http://sso-vouch-proxy.default.svc:9090/validate"
nginx.ingress.kubernetes.io/auth-signin: "https://vouch.example.com/login?url=$scheme://$http_host$request_uri"
```

`vouch.example.com` (the `/login` and `/auth` endpoints) must be reachable by users: enable
`ingress` or route it yourself. Any other Vouch setting is a `VOUCH_*` or `OAUTH_*` variable in
`extraEnvVars`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vouch-proxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/vouch-proxy@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/vouch-proxy` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `1` | Sessions are signed JWTs: any replica validates them. |
| `vouch.domains` | `[]` | Domains the session cookie is set for. |
| `vouch.allowAllUsers` / `whiteList` | `false` / `[]` | Who may log in. |
| `vouch.cookie.secure` / `domain` | `true` / `""` | Cookie flags. |
| `vouch.jwtSecret` | `""` | Session signing secret. Empty: generated and kept across upgrades. |
| `oauth.provider` | `oidc` | `oidc`, `google`, `github`, `azure`, `adfs`, and others. |
| `oauth.clientId` / `clientSecret` | `""` | Provider client credentials. |
| `oauth.authUrl` / `tokenUrl` / `userInfoUrl` | `""` | Provider endpoints (OIDC). |
| `oauth.scopes` | `[openid, email, profile]` | |
| `oauth.callbackUrl` | `""` | Public `/auth` URL users return to. |
| `existingSecret` | `""` | Secret with keys `client-secret` and `jwt-secret`. |
| `tls.enabled` | `false` | HTTPS on Vouch's listener with the chart's certificate. |
| `service.type` / `port` | `ClusterIP` / `9090` | |
| `ingress.enabled` | `false` | Ingress for the public `/login` and `/auth` endpoints. |
| `resources` | 25m / 32Mi requests, 500m / 128Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **Configured by environment.** Every setting is a `VOUCH_*` / `OAUTH_*` variable; the client
  secret and JWT secret come from a Secret. Vouch reads TLS only from `config.yml`, so with
  `tls.enabled` a two-line `config.yml` is mounted at `/vouch/config`.
- **The JWT secret survives upgrades**, so users stay signed in.
- **Probes** hit `/healthcheck`.

Vouch Proxy is MIT licensed.

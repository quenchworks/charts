# Quenchworks zero-trust-access-stack

A private WireGuard mesh whose devices join by signing in: [Headscale](https://github.com/juanfont/headscale)
0.29.7 (a self-hosted Tailscale control server) with [Authentik](https://github.com/goauthentik/authentik)
2026.8.5 as its OIDC identity provider. The stack creates the OIDC client in Authentik with an
Authentik blueprint and wires Headscale to it at install. All images are QuenchWorks (nonroot,
CVE-gated at build, pinned by digest, cosign-signed).

## Install

```bash
helm install access oci://ghcr.io/quenchworks/charts/zero-trust-access-stack -n access --create-namespace \
  --set headscale.serverUrl=https://hs.example.com \
  --set headscale.oidcIssuer=https://auth.example.com/application/o/headscale/
```

Expose Headscale at `serverUrl` and Authentik at the issuer's host (Ingress or a load balancer).
Then on a device: `tailscale up --login-server=https://hs.example.com`, open the printed URL,
sign in. People are managed in Authentik; the bootstrap admin is `akadmin`, password in the
Secret `zt-secrets` (key `bootstrap-password`).

## What the stack sets up

- Secret `zt-secrets`: the OIDC client secret, Authentik's bootstrap admin password and a
  bootstrap API token, generated once and kept across upgrades and on uninstall.
- Authentik blueprint `zt-headscale.yaml`: an OAuth2 provider (client ID `headscale`, the
  secret above, redirect URI `<serverUrl>/oidc/callback`, authorization-code and refresh-token
  grants, RS256 signing) and the application `headscale`.
- Headscale's config: the chart's default plus an `oidc` block (issuer, client, PKCE), and an
  init container that holds Headscale until Authentik serves the application, because
  Headscale reads the issuer once at startup and otherwise falls back to CLI-only registration.

## Values

| Key | Default | Notes |
|---|---|---|
| `headscale.serverUrl` | in-cluster `zt-headscale` URL | the `--login-server` devices use; also sets the redirect URI |
| `headscale.oidcIssuer` | in-cluster `zt-authentik` URL | must be reachable by browsers |
| `headscale.config` | chart default + `oidc` | full Headscale `config.yaml`, rendered with `tpl` |
| `authentik.*` | | passes to the [authentik chart](../authentik) |

## Notes

- One stack per namespace: Headscale, Authentik and the Secret have fixed names
  (`zt-headscale`, `zt-authentik`, `zt-secrets`).
- Authentik re-reads a changed blueprint on its periodic discovery, not at once. After changing
  `headscale.serverUrl` on an upgrade, re-apply it from the admin UI (System, Blueprints) or
  wait for the next run.
- Headscale 0.29 shows a confirmation page after sign-in; the device joins when the user confirms.
- The init container uses the authentik image; keep its digest equal to the authentik subchart's.

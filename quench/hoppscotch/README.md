# Quenchworks Hoppscotch

Hardened [Hoppscotch](https://github.com/hoppscotch/hoppscotch): an open-source API development platform for REST,
GraphQL, WebSocket and realtime APIs, with team workspaces. Every image is built from source (the backend, the
web app with its desktop bundle server, and the admin dashboard), runs as uid 1001 on a read-only rootfs and is
CVE-gated at build, cosign-signed and pinned by digest.

The chart runs the self-hosted layout as separate services: the **backend** (GraphQL and REST, auth, team
collections; an init container applies the database migrations), the **web** app and the **admin** dashboard, on
the bundled QuenchWorks PostgreSQL. `domain` serves the web app with the backend on `/graphql` and `/v1`;
`adminDomain` serves the admin dashboard.

## Install

```bash
helm install hopp oci://ghcr.io/quenchworks/charts/hoppscotch \
  --set domain=hoppscotch.example.com --set adminDomain=hoppscotch-admin.example.com \
  --set ingress.enabled=true --set ingress.className=nginx \
  --set 'ingress.tls[0].hosts[0]=hoppscotch.example.com' \
  --set 'ingress.tls[0].hosts[1]=hoppscotch-admin.example.com' --set 'ingress.tls[0].secretName=hoppscotch-tls'
```

Open the admin dashboard first: the first user to sign in becomes the administrator and sets up the sign-in
providers (email, GitHub, Google, Microsoft, OIDC) and SMTP.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | required | The public host of the web app and the backend |
| `adminDomain` | required | The public host of the admin dashboard |
| `publicScheme` | `https` | `http` only for testing |
| `backend.trustProxy` | `false` | Take the client IP from X-Forwarded-For (set `true` behind your ingress) |
| `backend.extraOrigins` | `[]` | More origins the backend accepts |
| `viteEnv` | `{}` | Extra `VITE_*` settings for the web app and the admin dashboard |
| `secret.existingSecret` | `""` | Your own `data-encryption-key` (32 characters) and `bundle-signing-secret` |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; `false` uses `externalDatabase.*` |
| `ingress.enabled` | `false` | One Ingress for both hosts |
| `networkPolicy.enabled` | `true` | Ingress allowed on the app ports only |

Keep the data encryption key: the backend encrypts the stored provider and SMTP settings with it. The chart
generates it once and keeps it on upgrade.

The desktop app connects to `domain`: the web pod's webapp-server serves its signed bundle on
`/desktop-app-server`, with a signing key derived from `bundle-signing-secret`, so it stays the same across
restarts.

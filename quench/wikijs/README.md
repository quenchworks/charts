# Quenchworks Wiki.js

Hardened [Wiki.js](https://github.com/requarks/wiki): a wiki with Markdown and visual editors, Git sync and many
authentication providers, on PostgreSQL. The image builds the frontend, the content blocks and the backend from
source; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build, cosign-signed and pinned by
digest.

The chart runs on the bundled QuenchWorks PostgreSQL and sets the first administrator from a generated Secret
(upstream would create `admin@example.com` with the password `12345678`).

## Install

```bash
helm install wiki oci://ghcr.io/quenchworks/charts/wikijs --set auth.email=you@example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=wiki.example.com' \
  --set 'ingress.tls[0].hosts[0]=wiki.example.com' --set 'ingress.tls[0].secretName=wiki-tls'
kubectl get secret wiki-wikijs -o jsonpath='{.data.password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.email`, `auth.password` | `admin@example.com`, generated | The first administrator, created on the first start |
| `auth.existingSecret` | `""` | A Secret with key `password` instead |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.*` with a password Secret |
| `persistence.size` | `5Gi` | `/wiki/data`: cache and Git-sync clones |
| `settings` | `{}` | More environment variables (`LOG_LEVEL`, `OFFLINE`, `DB_SCHEMA`) |
| `ingress.*` | off | Wiki.js has no TLS listener: terminate TLS at the Ingress |

The Puppeteer extension (server-side re-render) is not in the image: it downloads Chrome, and editing renders in
the browser without it.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/wikijs \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

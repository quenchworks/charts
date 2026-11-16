# Quenchworks Zipline

Hardened [Zipline](https://github.com/diced/zipline): file and image sharing with a web UI, ShareX/Flameshot uploads,
URL shortening, folders, invites, OAuth and passkeys. The image builds the Node app from source with pnpm and keeps
a production-only `node_modules`; it runs as uid 1001 on a read-only root filesystem and is CVE-gated at build,
cosign-signed and pinned by digest. The chart bundles the QuenchWorks PostgreSQL chart.

A post-install Job creates the super-admin through Zipline's first-setup API, so `/setup` is never left open.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/zipline \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=files.example.com' \
  --set 'ingress.tls[0].hosts[0]=files.example.com' --set 'ingress.tls[0].secretName=files-tls' \
  --set settings.CORE_RETURN_HTTPS_URLS=true
kubectl get secret files-zipline -o jsonpath='{.data.password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.username`, `auth.password` | `admin`, generated | The super-admin, created after install; kept on upgrade with the generated `CORE_SECRET` |
| `postgresql.enabled` | `true` | The bundled QuenchWorks PostgreSQL chart |
| `externalDatabase.existingSecret` | `""` | A Secret with `DATABASE_URL` for your own PostgreSQL |
| `settings` | `{}` | More Zipline variables (S3 datasource, domains, size limits, OAuth) |
| `persistence.size` | `10Gi` | Uploaded files (`/var/lib/zipline/uploads`) |
| `ingress.*` | off | Zipline has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/zipline \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

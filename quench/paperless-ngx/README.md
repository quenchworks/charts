# Quenchworks Paperless-ngx

Hardened [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx): a document management system that scans,
OCRs, indexes and archives your paper documents. The image builds the Angular UI and the Django app from source,
rebuilds every Rust extension (the tantivy search index, pydantic-core, granian, rpds-py, watchfiles) so their crates
are scanned, and ships Tesseract (English), Ghostscript, qpdf, ImageMagick and Poppler. It runs as uid 1001 on a
read-only root filesystem and is CVE-gated at build, cosign-signed and pinned by digest. The optional AI features
(LLM classification and chat: torch, llama-index) are left out.

The chart runs one pod with the web server, the Celery worker, the Celery scheduler and the consume-folder watcher,
on the bundled QuenchWorks PostgreSQL and Valkey. Init steps create the folders, migrate the database, check the
search index and create the first admin; `PAPERLESS_SECRET_KEY` and the admin password are generated.

## Install

```bash
helm install docs oci://ghcr.io/quenchworks/charts/paperless-ngx \
  --set settings.PAPERLESS_URL=https://docs.example.com \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=docs.example.com' \
  --set 'ingress.tls[0].hosts[0]=docs.example.com' --set 'ingress.tls[0].secretName=docs-tls'
kubectl get secret docs-paperless-ngx -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Sign in as `admin` with that password and change it under My Profile.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` / `admin.password` | `admin` / generated | The first superuser, created once |
| `secret.existingSecret` | `""` | A Secret with `secret-key` and `admin-password` instead of generated ones |
| `persistence.size` | `20Gi` | One volume for data, media and the consume folder |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.*` |
| `valkey.enabled` | `true` | The bundled Valkey; or `externalRedis.existingSecret` with a `redis://` URL |
| `consumer.enabled` | `true` | Watch `/var/lib/paperless/consume` for dropped files |
| `settings` | `{}` | More `PAPERLESS_*` variables: `PAPERLESS_URL` (needed behind an Ingress), `PAPERLESS_TIME_ZONE` |
| `ingress.*` | off | Paperless has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/paperless-ngx \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

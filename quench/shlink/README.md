# Quenchworks Shlink

Hardened [Shlink](https://github.com/shlinkio/shlink), the self-hosted URL shortener, CVE-gated,
cosign-signed and pinned by digest. The image is the release built with composer on PHP 8.4 and
served by RoadRunner, both built from source, on a nonroot Wolfi base.

## Install

```bash
helm install links oci://ghcr.io/quenchworks/charts/shlink --set defaultDomain=s.example.com
```

`defaultDomain` is required: it is the domain your short URLs live on. Point it at this Service
through an Ingress or a LoadBalancer. `httpsEnabled` (default `true`) makes Shlink build
`https://` short URLs; set it to `false` when the domain is served over plain HTTP.

## API key

The chart generates a REST API key into the Secret `<release>-shlink-api-key` and passes it as
`INITIAL_API_KEY`, which Shlink creates on its first start. Use it from shlink-web-client or curl
(`X-Api-Key` header). Bring your own with `apiKey.existingSecret`.

## Workers

`workers.web` (4) and `workers.task` (2) size RoadRunner's PHP pools. Shlink's own default is one
worker per CPU of the node for each pool, which runs out of memory on large nodes.

## Storage

SQLite, cache and locks live in `/etc/shlink/data` on a PersistentVolumeClaim (one replica,
`Recreate`). For PostgreSQL or MySQL set `settings.DB_DRIVER` with `DB_HOST`, `DB_NAME` and
`DB_USER`, and pass `DB_PASSWORD` through `extraEnvVarsSecret`.

## TLS

`tls.enabled` puts a caddy sidecar (our image, pinned by digest) in front of Shlink on 8443. The
certificate comes from `tls.existingSecret`, then cert-manager, else a Helm-generated CA.

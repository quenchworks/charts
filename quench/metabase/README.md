# Quenchworks Metabase

Hardened [Metabase](https://github.com/metabase/metabase) open-source edition,
self-service BI and dashboards, 0-CVE, cosign-signed and pinned by digest. The
image is the official uberjar on Java 25, with its bundled lz4-java swapped to
a fixed release.

## Install

```bash
helm install metabase oci://ghcr.io/quenchworks/charts/metabase
kubectl port-forward svc/metabase-metabase 3000
```

The first visit runs Metabase's setup wizard. The first start migrates the
application database, which takes a few minutes; the startup probe allows 15.

## Application database

By default Metabase stores its own data (users, questions, dashboards) in the
bundled PostgreSQL subchart. For an external PostgreSQL:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.internal
  database: metabase
  username: metabase
  existingSecret: metabase-db
  existingSecretPasswordKey: password
```

An init container waits until the database accepts connections before
Metabase starts.

## Encryption key

Metabase encrypts the connection details of every database you connect with
`MB_ENCRYPTION_SECRET_KEY`. The chart generates one and keeps it across
upgrades in the Secret `<release>-metabase`, key `encryption-key`. Back it up,
or bring your own with `encryptionKey.existingSecret`. Without the key the
saved connections cannot be read.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/metabase \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `postgresql.enabled` | `true` | Bundled PostgreSQL for the application database |
| `externalDatabase.*` | | External PostgreSQL when the subchart is off |
| `encryptionKey.value` / `existingSecret` | generated | Key for saved connection details |
| `siteUrl` | `""` | Public URL (`MB_SITE_URL`) |
| `javaMaxRamPercentage` | `75` | JVM heap as a share of the memory limit |
| `resources` | 1.5Gi / 3Gi memory | Metabase needs about 1 GiB to start |
| `waitForDatabase.enabled` | `true` | Init container that waits for PostgreSQL |
| `ingress.enabled` | `false` | Ingress |
| `service.port` | `3000` | Service port |

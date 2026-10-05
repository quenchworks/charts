# Quenchworks Mongo Express

Hardened [Mongo Express](https://github.com/mongo-express/mongo-express), the web admin UI
for MongoDB: browse databases and collections, edit, import and export documents, and run
queries. It works with MongoDB and with MongoDB-compatible servers such as the catalog's
FerretDB. The chart runs the stateless Node UI on port 8081 and bundles no database; you
point it at the server to manage. The image is minimal, runs nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, ships 0-CVE, is cosign-signed
(keyless / Sigstore), and the chart pins it by the signed digest, never a tag.

Mongo Express gives whoever logs in full read-write access to every database the URL's
user can reach. Basic auth is on by default with a generated password; keep the Service
internal, or set `readOnly=true` for a browse-only console.

## Install

```bash
helm install mx oci://ghcr.io/quenchworks/charts/mongo-express \
  --set mongodb.url='mongodb://admin:secret@mongodb:27017/?authSource=admin'
kubectl get secret mx-mongo-express -o jsonpath='{.data.basic-auth-password}' | base64 -d; echo
kubectl port-forward svc/mx-mongo-express 8081:8081   # http://127.0.0.1:8081, user admin
```

The URL carries a password, so the chart stores it in a Secret. To keep it out of your
values, put it in your own Secret:

```yaml
mongodb:
  existingSecret: mongo-admin-url
  existingSecretUrlKey: url
```

FerretDB authenticates with its PostgreSQL user:
`mongodb://postgres:<password>@<release>-ferretdb:27017/`.

The basic-auth password and the session and cookie secrets are generated on first install
and kept on upgrade. `basicAuth.existingSecret` supplies the password from your own Secret.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mongo-express \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/mongo-express --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `mongodb.url` | `""` | Required unless `mongodb.existingSecret` is set. |
| `mongodb.existingSecret` / `.existingSecretUrlKey` | `""` / `mongodb-url` | A Secret holding the URL. |
| `listAllDatabases` | `true` | `false` shows only the database named in the URL. |
| `readOnly` | `false` | Disables every write in the UI. |
| `baseUrl` | `/` | Path prefix, e.g. `/mongo/`. |
| `basicAuth.enabled` | `true` | |
| `basicAuth.username` / `.password` | `admin` / generated | Or `.existingSecret`. |
| `sessionSecret`, `cookieSecret` | generated | Set both for several replicas without sticky sessions. |
| `networkPolicy.mongodbPort` | `27017` | The only egress port besides DNS. |
| `ingress.enabled` | `false` | |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars` for any other `ME_CONFIG_*` setting, `extraVolumes`,
`sidecars`, probe overrides, security contexts) work as in every Quenchworks chart.

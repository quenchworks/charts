# Quenchworks FerretDB

Hardened [FerretDB](https://www.ferretdb.com/) on a minimal, nonroot, 0-CVE image
pinned by digest. FerretDB speaks the MongoDB wire protocol and stores data in
PostgreSQL with the DocumentDB extension, so it is a stateless proxy: this chart runs
a Deployment that can scale behind the service. It needs a DocumentDB-extended
PostgreSQL backend — the companion
[postgres-documentdb](https://ghcr.io/quenchworks/charts/postgres-documentdb) chart.

## Install

Deploy the backend, then point FerretDB at it:

```bash
helm install docdb oci://ghcr.io/quenchworks/charts/postgres-documentdb \
  --set auth.password='change-me'

helm install fdb oci://ghcr.io/quenchworks/charts/ferretdb \
  --set backend.url='postgres://postgres:change-me@docdb-postgres-documentdb:5432/postgres'
```

Then connect with any MongoDB client:

```bash
mongosh 'mongodb://fdb-ferretdb:27017/'
```

You can instead keep the URL in your own Secret:

```bash
helm install fdb oci://ghcr.io/quenchworks/charts/ferretdb \
  --set backend.existingSecret=my-pg --set backend.existingSecretUrlKey=url
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ferretdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ferretdb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `backend.url` | `""` | Full `postgres://` URL to the DocumentDB-extended PostgreSQL. Stored in a Secret, read via `FERRETDB_POSTGRESQL_URL_FILE`. |
| `backend.existingSecret` | `""` | Use a Secret you manage instead of `backend.url`. |
| `backend.existingSecretUrlKey` | `postgresql-url` | Key in that Secret holding the URL. |
| `ferretdb.auth` | `true` | Authenticate clients against the backend roles. |
| `ferretdb.extraArgs` | `[]` | Extra FerretDB flags. |
| `service.port` | `27017` | MongoDB wire protocol. |
| `service.debugPort` | `8088` | Metrics + `/debug/livez`, `/debug/readyz` (probes). |
| `autoscaling.enabled` | `false` | HPA on CPU (the proxy is stateless). |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the backend-URL Secret mount and the in-memory `/state` dir are
present; `/state` is an emptyDir. Reachable only inside the cluster (the
NetworkPolicy restricts ingress to the release namespace).

## Notes

You must provide exactly one of `backend.url` or `backend.existingSecret`. Depends on
the `quench-common` library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

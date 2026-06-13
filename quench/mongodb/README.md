# Quenchworks MongoDB Community Server

> **LICENSE — READ THIS.** MongoDB Community Server is **SSPL-1.0**, which is
> **NOT an OSI-approved open-source license** — the Open Source Initiative
> explicitly declined the SSPL. **MongoDB is NOT open source.** This chart is
> **caution tier**. If license cleanliness matters (it usually does), prefer the
> truly-open, MongoDB-wire-compatible QuenchWorks alternatives that are already
> shipped: **[FerretDB](../ferretdb) + the standalone [documentdb](../documentdb)
> chart** (Apache-2.0 / PostgreSQL-licensed). The bundled `mongosh` shell is
> separately Apache-2.0.

MongoDB Community Server 8.0.26 on a nonroot, 0-CVE Wolfi image pinned by digest,
read-only root filesystem. MongoDB wire protocol on port **27017**.

On first boot (fresh data dir) with auth enabled, the entrypoint starts `mongod`
no-auth, creates the root user in the `admin` database, then restarts `mongod`
with `--auth`. A random root password is generated into a Secret if you do not
set one.

## Install

```bash
helm install mongo oci://ghcr.io/quenchworks/charts/mongodb \
  --set auth.rootPassword='change-me'
```

A root password is generated into a Secret if you do not set one.

## Connect

`mongosh` ships in-image, so you can exec straight into the pod:

```bash
PW=$(kubectl get secret mongo-mongodb -o jsonpath='{.data.mongodb-root-password}' | base64 -d)
kubectl exec -it mongo-mongodb-0 -- \
  mongosh "mongodb://root:${PW}@localhost:27017/admin"
```

```js
db.gate.insertOne({ k: "quench" })
db.gate.findOne()
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mongodb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mongodb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `auth.enabled` | `true` | Root user bootstrapped on first boot; `mongod` runs with `--auth`. If `false`, mongod runs **without auth** (NetworkPolicy is the boundary). |
| `auth.rootUsername` | `root` | `MONGO_INITDB_ROOT_USERNAME`. |
| `auth.rootPassword` | `""` | Generated into a Secret if empty. |
| `auth.database` | `""` | Optional `MONGO_INITDB_DATABASE` (initial db). |
| `auth.existingSecret` | `""` | Use an existing Secret instead. |
| `primary.persistence.enabled` | `true` | 8Gi PVC mounted at `/data` (dbpath `/data/db`, logs/socket `/data/log`). |
| `service.port` | `27017` | MongoDB wire protocol. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace, port 27017. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. A single writable PVC at `/data` holds the dbpath (`/data/db`) and the
log dir (`/data/log`, which also holds the relocated unix socket and the `mongosh`
HOME). When `auth.enabled=false`, there is no authentication — the NetworkPolicy
is the only boundary.

## Notes

Single replica. `mongos` and the MongoDB database tools are deliberately not
shipped; `mongosh` (Apache-2.0) is in-image as a client/bootstrap shell. Replica
sets / sharding are a tracked follow-up. Depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Postgres Operator

Hardened [Zalando Postgres Operator](https://github.com/zalando/postgres-operator): highly available PostgreSQL
clusters on Patroni, declared as `postgresql` resources, with rolling updates, failover, connection pooling and
clones. The operator image is a static Go binary built from source; every cluster it creates runs the QuenchWorks
[Spilo](https://github.com/zalando/spilo) image (PostgreSQL 18, Patroni, WAL-G, pgvector, pg_cron), built on Wolfi.
Both are CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install pgo oci://ghcr.io/quenchworks/charts/postgres-operator --namespace postgres-operator --create-namespace
```

Then declare a cluster:

```yaml
apiVersion: acid.zalan.do/v1
kind: postgresql
metadata: { name: acid-main, namespace: default }
spec:
  teamId: acid
  numberOfInstances: 3
  postgresql: { version: "18" }
  volume: { size: 10Gi }
  users: { app: [createdb] }
  databases: { app: app }
```

The cluster name must start with the `teamId`. Patroni keeps its leader in the Kubernetes API (endpoints), so no
etcd is needed. The operator stores each user's password in a Secret named
`<user>.<cluster>.credentials.postgresql.acid.zalan.do`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `spilo.image.*` | the QuenchWorks spilo digest | The database image every cluster runs; set as the operator's `docker_image` |
| `config` | see values.yaml | Operator ConfigMap keys ([operator parameters](https://github.com/zalando/postgres-operator/blob/master/docs/reference/operator_parameters.md)); `docker_image`, `spilo_runasuser`, `spilo_runasgroup`, `spilo_fsgroup` are always set from `spilo` |
| `config.watched_namespace` | `*` | Namespaces the operator watches |
| `serviceAccount.automountServiceAccountToken` | `true` | The operator needs the API server |
| `networkPolicy.allowExternal` | `false` | The operator API (8080) is reachable from the release namespace only |

Clusters run as postgres (uid 101, gid 103). The CRDs (`postgresqls`, `postgresteams`) ship in `crds/` and the
operator's own CRD registration is off; Helm does not upgrade CRDs, so apply the new ones from `crds/` before an
upgrade that changes them.

## Not included yet

- **Connection pooler and logical backup images.** Both are off unless a cluster asks for them, and the operator
  defaults to upstream's images for them: set `config.connection_pooler_image` and
  `config.logical_backup_docker_image` before turning them on.
- **Older PostgreSQL majors.** The Spilo image carries PostgreSQL 18 only, so in-place major upgrades from 14 to 17
  are not available, and timescaledb is not included.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/postgres-operator \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

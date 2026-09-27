# Quenchworks ProxySQL

Hardened [ProxySQL](https://github.com/sysown/proxysql), the MySQL-protocol
proxy, on a minimal, nonroot, 0-CVE image, cosign-signed and pinned by digest.
It pools connections, splits reads from writes, routes queries by rule, and
fails over between MySQL or MariaDB backends.

## Install

```bash
helm install sql oci://ghcr.io/quenchworks/charts/proxysql \
  --set 'mysqlServers[0].hostname=db-mariadb' \
  --set 'mysqlUsers[0].username=app' --set 'mysqlUsers[0].password=secret'
```

Applications connect to `sql-proxysql:3306` as if it were MySQL. ProxySQL logs
in to the backend with the same username and password the client used, so every
user in `mysqlUsers` must also exist on the backends.

## How the config works

The chart renders `proxysql.cnf` from values into a Secret, since it carries
passwords. ProxySQL reads that file only when its datadir is empty, and the
datadir is an emptyDir, so every pod starts from values. A change made at
runtime over the admin interface lasts until the pod restarts.

## Admin interface

The admin interface is on its own ClusterIP Service, `<release>-proxysql-admin`
port 6032, and the NetworkPolicy allows it from the release namespace only.
Log in as `radmin`. When `admin.password` is empty, the chart generates one on
install and keeps it on upgrade:

```bash
kubectl get secret sql-proxysql -o jsonpath='{.data.admin-password}' | base64 -d
```

The built-in `admin` user works only from inside the pod; ProxySQL enforces that.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/proxysql \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/proxysql --owner quenchworks`.

## Values

| Key | Default | Description |
|---|---|---|
| `mysqlServers` | `[]` | Backends: `hostname`, `port`, `hostgroup`, `weight` |
| `mysqlUsers` | `[]` | Frontend users: `username`, `password`, `defaultHostgroup` |
| `replicationHostgroups` | `[]` | `writerHostgroup`/`readerHostgroup` pairs for read/write split |
| `monitor.username` / `.password` | `monitor` | Account the monitor uses on backends |
| `admin.username` | `radmin` | Remote admin account |
| `admin.password` | `""` | Generated and kept when empty |
| `extraConfig` | `""` | Raw libconfig appended to `proxysql.cnf` (query rules and so on) |
| `threads` | `4` | Worker threads |
| `maxConnections` | `2048` | Client connection limit |
| `service.port` | `3306` | MySQL Service port |
| `service.adminPort` | `6032` | Admin Service port |
| `networkPolicy.allowExternal` | `true` | Allow MySQL clients from other namespaces |

The common quench-common knobs (`nodeSelector`, `tolerations`, `extraVolumes`,
`sidecars`, probes and so on) are available as in every QuenchWorks chart.

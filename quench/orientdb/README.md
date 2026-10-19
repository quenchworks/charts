# QuenchWorks OrientDB

Hardened [OrientDB](https://orientdb.org/) Community on a minimal, nonroot, 0-CVE
image pinned by digest. OrientDB is a multi-model database (graph, document,
key-value) queried with an SQL dialect. The binary protocol is on port `2424`; the
HTTP API and Studio are on `2480`. License: Apache-2.0.

> **Standalone only, no distributed mode.** The upstream dist bundles Hazelcast
> 3.12.13 for distributed mode, and its CVEs are fixed only on Hazelcast 5.x, which
> OrientDB 3.2 cannot use. The image removes Hazelcast, the distributed plugin and
> `dserver.sh`, so this chart runs one replica.

## Install

```bash
helm install odb oci://ghcr.io/quenchworks/charts/orientdb
```

The server root password lives in a Secret. If you do not set `auth.password`, a
random 24-character one is generated and kept across upgrades. To bring your own
Secret, set `auth.existingSecret` (key `auth.existingSecretPasswordKey`).

Databases are stored on a PersistentVolumeClaim mounted at
`/opt/orientdb/databases`. The server config is seeded from the image on every
start and the root user is written from the Secret, so the Secret is the source of
truth for the root password.

## Use it

```bash
PW="$(kubectl get secret odb-orientdb -o jsonpath='{.data.root-password}' | base64 -d)"
kubectl port-forward svc/odb-orientdb 2480:2480 &

# create a database, then run SQL over the HTTP API
curl -u "root:$PW" -X POST http://127.0.0.1:2480/database/demo/plocal
curl -u "root:$PW" -H 'Content-Type: application/json' \
  -d '{"command":"CREATE CLASS Thing"}' http://127.0.0.1:2480/command/demo/sql
curl -u "root:$PW" -H 'Content-Type: application/json' \
  -d "{\"command\":\"INSERT INTO Thing SET name = 'quench'\"}" http://127.0.0.1:2480/command/demo/sql
curl -u "root:$PW" -H 'Content-Type: application/json' \
  -d '{"command":"SELECT FROM Thing"}' http://127.0.0.1:2480/command/demo/sql
```

Studio is served at `http://127.0.0.1:2480/studio/index.html`.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `auth.password` | `""` | Root password; generated when empty |
| `auth.existingSecret` | `""` | Use an existing Secret for the root password |
| `javaOpts.memory` | `-Xms512m -Xmx512m` | JVM heap flags (`ORIENTDB_OPTS_MEMORY`) |
| `javaOpts.settings` | `""` | Extra `-D` server settings (`ORIENTDB_SETTINGS`) |
| `persistence.enabled` | `true` | PVC for `databases/` |
| `persistence.size` | `8Gi` | PVC size |
| `service.binaryPort` | `2424` | Binary protocol port |
| `service.httpPort` | `2480` | HTTP API and Studio port |
| `networkPolicy.enabled` | `true` | Allow ingress only from pods in the namespace |
| `ingress.enabled` | `false` | Ingress for the HTTP API and Studio |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/orientdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

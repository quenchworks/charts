# Quenchworks RethinkDB

[RethinkDB](https://rethinkdb.com) is a document database that pushes query
results to clients as the data changes (changefeeds). This chart runs the
QuenchWorks rethinkdb image as a StatefulSet with a PVC. The image is nonroot,
0 fixable CVEs, pinned by digest and cosign-signed.

## Install

```bash
helm install rdb oci://ghcr.io/quenchworks/charts/rethinkdb
PASSWORD=$(kubectl get secret rdb-rethinkdb -o jsonpath='{.data.password}' | base64 -d)
```

Connect a driver to `rdb-rethinkdb.<namespace>.svc:28015` as `admin` with that
password.

## Values

| Key | Default | Notes |
|---|---|---|
| `auth.existingSecret` | `""` | Secret with a `password` key; generated when empty |
| `extraArgs` | `[]` | extra rethinkdb flags (`--cache-size`, ...) |
| `persistence.enabled` | `true` | a PVC mounted at `/data` |
| `service.exposeAdmin` | `false` | add the web admin UI (port 8080) to the Service |

## Notes

- One server. RethinkDB clustering (`--join`) is not wired up yet.
- The admin password is set when the data directory is first created; changing
  the Secret later does not change it. Use the web UI or ReQL for that.
- The web admin UI has no login. It stays off the Service unless
  `service.exposeAdmin=true`; reach it with
  `kubectl port-forward pod/rdb-rethinkdb-0 8080:8080`.

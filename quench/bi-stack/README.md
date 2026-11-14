# Quenchworks bi-stack

Dashboards over a columnar store in one install: [Metabase](https://github.com/metabase/metabase)
0.63.22 with [ClickHouse](https://github.com/ClickHouse/ClickHouse) 26.7.37.6, and PostgreSQL as
Metabase's application database. All images are QuenchWorks (nonroot, CVE-gated at build, pinned
by digest, cosign-signed). A Job runs Metabase's first-run setup and adds ClickHouse as the data
source "ClickHouse", so the first sign-in lands on a working Metabase.

## Install

```bash
helm install bi oci://ghcr.io/quenchworks/charts/bi-stack -n bi --create-namespace \
  --set admin.email=you@example.com
kubectl -n bi get secret bi-secrets -o jsonpath='{.data.metabase-admin-password}' | base64 -d
kubectl -n bi port-forward svc/bi-metabase 3000:3000
```

Sign in at http://127.0.0.1:3000 as `admin.email` with that password, then change it.

## Values

| Key | Default | Notes |
|---|---|---|
| `admin.email` | `admin@example.com` | the Metabase administrator the Job creates |
| `admin.firstName`, `admin.lastName` | `Metabase`, `Admin` | |
| `admin.siteName` | `QuenchWorks BI` | |
| `metabase.*` | | passes through to the metabase chart (ingress, TLS, resources) |
| `clickhouse.*` | | passes through to the clickhouse chart (persistence, TLS, resources) |
| `setupJob.clickhouse.*` | `bi-clickhouse:8123`, user `default`, database `default` | the data source the Job adds |

## Notes

- One stack per namespace: the Services are `bi-metabase` and `bi-clickhouse` (fixed with
  `fullnameOverride`), because the setup Job names them.
- The Secret `bi-secrets` holds the ClickHouse password and the Metabase administrator password.
  Both are generated once and kept on upgrade and uninstall (`helm.sh/resource-policy: keep`).
- The setup Job runs on every install and upgrade and changes nothing once Metabase is set up and
  a ClickHouse database exists. Changing `admin.*` after the first install has no effect: change
  the administrator in Metabase.
- Metabase connects to ClickHouse as the `default` user. For dashboards, create a read-only
  ClickHouse user and edit the data source in Metabase (Admin, Databases).

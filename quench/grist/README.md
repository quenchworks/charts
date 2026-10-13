# Grist

[Grist](https://www.getgrist.com) is a self-hosted spreadsheet-database: tables with
column types, relational references and Python formulas, plus a REST API. This chart
runs grist-core on the QuenchWorks grist image as a single-replica StatefulSet with
its SQLite home database and documents on a PVC. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install grist oci://ghcr.io/quenchworks/charts/grist --set adminEmail=you@example.com
kubectl port-forward svc/grist 8484:8484
```

Open http://127.0.0.1:8484.

## Login

With no login system configured, Grist uses its "minimal" login: every visitor is
signed in as `adminEmail` (Grist's default is `you@example.com`). Keep the Service
private (the NetworkPolicy allows only same-namespace clients by default), or set up
OIDC (`GRIST_OIDC_IDP_ISSUER`, `GRIST_OIDC_IDP_CLIENT_ID`, `GRIST_OIDC_IDP_CLIENT_SECRET`),
SAML or forward auth through `extraEnvVars` / `extraEnvVarsSecret` before exposing it.
Set `homeUrl` to the public URL when you put it behind an Ingress.

The chart generates `GRIST_SESSION_SECRET` once and keeps it across upgrades; without
it Grist signs cookies with a built-in constant. Bring your own with
`sessionSecret.existingSecret`.

## Formula sandbox

Grist evaluates formulas in Python. The image runs them in the pyodide sandbox
(`GRIST_SANDBOX_FLAVOR=pyodide`): Python compiled to WebAssembly, run by deno with read
and write access dropped before any formula runs and no network access. Upstream's
default image uses gVisor, which needs privileges a read-only nonroot pod does not have.
Each open document gets its own sandbox process, roughly 100-200Mi of memory; size
`resources` for the number of documents open at once.

## Storage

`/persist` on the PVC holds `home.sqlite3` (users, orgs, workspaces) and `docs/` (one
SQLite file per document). For an external PostgreSQL home database, set
`TYPEORM_TYPE=postgres` and `TYPEORM_HOST`, `TYPEORM_DATABASE`, `TYPEORM_USERNAME`,
`TYPEORM_PASSWORD` through `extraEnvVars` / `extraEnvVarsSecret`. Documents stay on the
PVC, so keep `replicaCount` at 1.

## Values

| Key | Default | Meaning |
|---|---|---|
| `adminEmail` | `""` | install admin, and the minimal-login user |
| `homeUrl` | `""` | public URL (APP_HOME_URL) |
| `sessionSecret.existingSecret` | `""` | your own Secret for GRIST_SESSION_SECRET |
| `persistence.enabled` | `true` | PVC for /persist |
| `persistence.size` | `5Gi` | PVC size |
| `service.port` | `8484` | Service port |
| `ingress.enabled` | `false` | an Ingress for the UI |
| `networkPolicy.enabled` | `true` | restrict ingress to the namespace |
| `networkPolicy.allowExternal` | `false` | allow ingress from any source |

Pods run with a read-only root filesystem and all capabilities dropped; `/tmp` is an
emptyDir (uploads and the deno cache).

The release gate installs the chart on kind with persistence on, creates a document
through the REST API, writes a row to a table with a formula column, reads the value the
sandbox computed, deletes the pod and reads the same value back after it restarts.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

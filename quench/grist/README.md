# Grist

[Grist](https://www.getgrist.com) is a self-hosted spreadsheet-database: tables with
column types, relational references and Python formulas, plus a REST API. This chart
runs grist-core on the QuenchWorks grist image as a single-replica StatefulSet with
its SQLite home database and documents on a PVC. The image is nonroot, cosign-signed
and pinned by digest.

> **Changed in 0.0.4 (2026-10-14):** formulas run in gVisor, not in pyodide under deno.
> Earlier versions shipped deno 2.9.7, whose binary hid fixable crate advisories
> (hickory-resolver, hickory-proto, rustls) from the scan; the image no longer contains deno.

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

Grist evaluates formulas in Python. The image runs them in gVisor
(`GRIST_SANDBOX_FLAVOR=gvisor`, upstream's default): each open document gets its own
`runsc` sandbox with its own kernel (the gVisor sentry), no network, a read-only view of
the Python runtime and the engine, and an empty filesystem everywhere else, so a formula
cannot reach the documents on `/persist`, the pod's environment or the cluster network.

Like upstream's image, `runsc` runs in Grist's unprivileged mode
(`GVISOR_FLAGS="-unprivileged -ignore-cgroups"`): the sandbox and its file proxy start as
the pod user without new namespaces or chroot. That is what lets it run in this chart's
default pod, which needs nothing extra: nonroot, all capabilities dropped, no privilege
escalation, a read-only root and the `RuntimeDefault` seccomp profile. Stock `runsc` cannot
start there; it needs `CAP_SYS_ADMIN` to create namespaces. The isolation of formulas rests
on the gVisor kernel, not on host namespaces around it. `runsc` is built from source with
that flag ported to current gVisor, since upstream's binary is a 2022 build.

Each sandbox is a few processes (sentry, file proxy, Python); size `resources` for the
number of documents open at once.

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
emptyDir (uploads and the `runsc` state under `/tmp/runsc`).

The release gate installs the chart on kind with persistence on, creates a document
through the REST API, writes a row to a table with formula columns, reads the value the
sandbox computed and the hostname the engine sees (`gristland`, the name `run.py` gives the
`runsc` sandbox, so the formula ran inside gVisor), checks the pod log for `flavor=gvisor`,
deletes the pod and reads the same value back after it restarts.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

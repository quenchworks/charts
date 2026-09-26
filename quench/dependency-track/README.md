# OWASP Dependency-Track

[Dependency-Track](https://dependencytrack.org) ingests CycloneDX SBOMs, tracks every
component across your projects and flags known vulnerabilities, policy violations and
outdated or license-risky dependencies. This chart runs the API server, the web UI and a
bundled PostgreSQL, all on QuenchWorks images: 0 fixable CVEs, nonroot, cosign-signed and
pinned by digest.

## Install

```sh
helm install dtrack oci://ghcr.io/quenchworks/charts/dependency-track
kubectl port-forward svc/dtrack-dependency-track 8080:8080
```

Open http://127.0.0.1:8080 and sign in as `admin` / `admin`; Dependency-Track makes you
change the password on first login. The first start runs the database migrations, so the
API pod takes a few minutes to go Ready.

CI pipelines upload SBOMs to the same address (`/api/v1/bom`) with an API key created in
the UI.

## What runs

- `<release>-dependency-track`: the web UI on nginx. It proxies `/api` to the API server,
  so the UI and the API share one Service and one Ingress.
- `<release>-dependency-track-api`: the API server (one replica, Recreate). A
  wait-for-db initContainer holds it until PostgreSQL accepts connections, because the
  server exits on a refused first connection instead of retrying.
- `<release>-postgresql`: the QuenchWorks PostgreSQL chart. The API server reads the
  password from the Secret that chart generates.

Everything durable lives in PostgreSQL; the API server's `/data` is an emptyDir for caches.

## Values

| Key | Default | Meaning |
|---|---|---|
| `apiServer.extraJavaOptions` | `""` | JVM flags appended to the image defaults |
| `apiServer.extraEnv` | `[]` | extra `DT_*` settings |
| `apiServer.resources` | 2Gi / 4Gi | the analyzer needs memory; do not go much lower |
| `frontend.enabled` | `true` | the web UI and its `/api` proxy |
| `service.port` | `8080` | the UI Service |
| `ingress.*` | off | an Ingress to the UI Service |
| `postgresql.enabled` | `true` | bundled PostgreSQL (`auth.database: dtrack`) |
| `externalDatabase.*` | | `url` (jdbc), `username`, `existingSecret` when bundled is off |

The release gate installs the chart on kind, then drives the API through the UI's proxy:
it reads `/api/version` (must match the appVersion), changes the admin's forced
password, logs in, and creates and reads back a project.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

# Quenchworks Mattermost

Hardened [Mattermost](https://mattermost.com/) **Team Edition** — a self-hosted team
collaboration and messaging platform (channels, DMs, file sharing) — on a minimal,
nonroot, 0-CVE image pinned by digest. The server is a single static Go binary that
runs as uid `1001` on a read-only root filesystem and listens on port `8065`.

Mattermost **requires PostgreSQL** for all relational data. This chart bundles the
Quenchworks PostgreSQL chart by default and can also point at an external database.
All server configuration is driven via `MM_*` environment variables (they override
`config.json`), so the config volume starts empty.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install chat oci://ghcr.io/quenchworks/charts/mattermost
```

## Connect

```bash
kubectl port-forward svc/chat-mattermost 8065:8065
# open http://127.0.0.1:8065/  and create the first admin account
```

Health check:

```bash
curl -fsS http://127.0.0.1:8065/api/v4/system/ping
# -> {"status":"OK"}
```

## Database

### Bundled (default)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart. Mattermost and
PostgreSQL share the deterministic credentials under `postgresql.auth`; the full
datasource DSN (`MM_SQLSETTINGS_DATASOURCE`) is derived from the subchart's service
(`<release>-postgresql:5432`) automatically and stored in the managed Secret.

```yaml
postgresql:
  enabled: true
  auth:
    username: mattermost
    password: ""        # generated into the Secret if empty
    database: mattermost
```

### External

Point at an existing PostgreSQL and disable the subchart:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: postgres.example.com
  port: 5432
  database: mattermost
  user: mattermost
  password: "s3cret"
  # or reference a Secret that supplies BOTH `db-password` and a full `datasource` DSN:
  existingSecret: ""
  existingSecretPasswordKey: db-password
```

## Storage

`/opt/mattermost/data` (uploaded files/attachments) is persisted via a
`volumeClaimTemplate` (`persistence.size`, default `10Gi`). The config, logs, plugins
and client/plugins directories are ephemeral `emptyDir`s so the root filesystem stays
read-only.

## SiteURL & ingress

Set `siteUrl` to the external URL Mattermost is reached on when fronting it with an
ingress/proxy:

```yaml
siteUrl: https://chat.example.com
```

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/mattermost` | Image repository |
| `image.digest` | pinned `sha256:…` | Image digest (never a tag) |
| `replicaCount` | `1` | Team Edition is single-node |
| `service.port` | `8065` | HTTP listener / service port |
| `siteUrl` | in-cluster svc DNS | Public URL (`MM_SERVICESETTINGS_SITEURL`) |
| `persistence.size` | `10Gi` | PVC size for `/opt/mattermost/data` |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart |
| `postgresql.auth.{username,password,database}` | `mattermost` / `""` / `mattermost` | Shared DB credentials |
| `externalDatabase.*` | `""` | External DB connection (when `postgresql.enabled=false`) |
| `networkPolicy.enabled` | `true` | Restrict traffic; egress opened to the DB port |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` |


| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mattermost \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

The bundled PostgreSQL image (`ghcr.io/quenchworks/images/postgresql`) verifies
the same way. Each build also ships an SPDX SBOM and SLSA provenance attestation;
verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/mattermost --owner quenchworks
gh attestation verify oci://ghcr.io/quenchworks/images/postgresql --owner quenchworks
```

## Uninstall

```bash
helm uninstall chat
```

The PVC provisioned for `/opt/mattermost/data` is retained by Kubernetes on
uninstall, as is the bundled PostgreSQL PVC. Delete them explicitly if you want
the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=chat
```

## Notes

Team Edition is single-node (HA/clustering is an Enterprise feature), so
`replicaCount` stays at 1. Depends on the `quench-common` library chart and the
Quenchworks `postgresql` chart, both pulled from
`oci://ghcr.io/quenchworks/charts`. The container runs as nonroot (uid 1001) on a
read-only root filesystem, and the image is pinned by digest.

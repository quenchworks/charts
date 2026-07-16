# Quenchworks WordPress

Hardened [WordPress](https://wordpress.org/) — the PHP content-management
system — on a minimal, nonroot, read-only-rootfs 0-CVE image pinned by digest
and cosign-signed. WordPress is served by a Wolfi **PHP-FPM + nginx** runtime
(supervisord): nginx listens on port 8080 (nonroot can't bind `<1024`) and
FastCGI-passes `.php` to php-fpm on `127.0.0.1:9000`. It runs as uid 1001.

WordPress needs an external **MySQL/MariaDB**. This chart bundles the
Quenchworks MySQL chart by default, provisions an uploads PVC at
`wp-content/uploads`, and supplies the `wp-config.php` the image intentionally
omits — that config reads every DB setting and auth salt from environment
variables injected from a managed Secret, so no secret is ever baked into the
image or written to disk.

## Install

```bash
# self-contained: bundles in-cluster MySQL + an uploads PVC
helm install blog oci://ghcr.io/quenchworks/charts/wordpress \
  --set mysql.auth.rootPassword="ChangeMeRoot" \
  --set mysql.auth.password="ChangeMe"
```

Then finish the five-minute install at `/wp-admin/install.php`. The DB password
and WordPress auth salts are injected from a managed Secret as `WORDPRESS_*` env
vars and read by `wp-config.php`, so they never appear in the pod's process
arguments. Reach the site over a port-forward:

```bash
kubectl port-forward svc/blog-wordpress 8080:8080
# site:    http://localhost:8080/
# install: http://localhost:8080/wp-admin/install.php
# admin:   http://localhost:8080/wp-admin/
```

To use an external MySQL/MariaDB instead, set `mysql.enabled=false` and fill in
`externalDatabase.*` (or `externalDatabase.existingSecret` carrying the password
key).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/wordpress \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/wordpress \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/wordpress` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Uploads PVC is ReadWriteOnce; keep at 1 unless uploads move off the PVC. |
| `wordpress.siteUrl` | `""` | Pins `WP_HOME`/`WP_SITEURL` (useful behind a proxy). Empty lets the wizard set them. |
| `wordpress.tablePrefix` | `wp_` | Database table prefix. |
| `resources.requests` | `250m / 256Mi` | CPU / memory requests. |
| `resources.limits` | `2 / 1Gi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | Public site + `/wp-admin` (nginx `http` port). |
| `persistence.enabled` | `true` | Provision the uploads PVC. When `false`, uses an `emptyDir` (uploads lost on restart). |
| `persistence.size` | `10Gi` | Uploads PVC size. |
| `persistence.mountPath` | `/var/www/html/wp-content/uploads` | Uploads mount path. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `mysql.enabled` | `true` | Deploy the bundled MySQL subchart. |
| `mysql.auth.rootPassword` | `""` | Generated into MySQL's own Secret if empty. |
| `mysql.auth.database` | `wordpress` | App database, created on first init. |
| `mysql.auth.username` | `wordpress` | DB user. |
| `mysql.auth.password` | `""` | Generated into this chart's managed Secret if empty. |
| `externalDatabase.host` | `""` | External DB host (when `mysql.enabled=false`). |
| `externalDatabase.port` | `3306` | External DB port. |
| `externalDatabase.database` | `wordpress` | External database name. |
| `externalDatabase.user` | `wordpress` | External DB user. |
| `externalDatabase.password` | `""` | External DB password (or use `existingSecret`). |
| `externalDatabase.existingSecret` | `""` | Secret carrying the DB password. |
| `externalDatabase.existingSecretPasswordKey` | `db-password` | Password key within that Secret. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace; opens the DB port + DNS on egress. |
| `networkPolicy.allowExternal` | `false` | Set `true` (behind an ingress/TLS proxy) to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

A stateless **Deployment** runs the PHP-FPM + nginx runtime. nginx serves the
whole site — public pages and `/wp-admin` — on container port 8080; the Service
maps the same port. Durable relational state (posts, users, options, comments)
lives in an external MySQL, deployed by default via the bundled subchart whose
primary Service is `<release>-mysql` on port 3306.

Because the root filesystem is read-only, three volumes are mounted:

- **`/var/www/html/wp-config.php`** — the chart-supplied config, mounted
  read-only from a ConfigMap via `subPath` so it doesn't shadow the docroot. It
  resolves the DB connection and the eight auth keys/salts from the pod
  environment at request time (php-fpm runs with `clear_env=no`).
- **`wp-content/uploads`** (`persistence.mountPath`) — user media, the only
  writable app path, backed by the PVC (or an `emptyDir` when
  `persistence.enabled=false`).
- **`/tmp`** — a writable `emptyDir` for nginx pid/temp and php sessions.

WordPress core, themes and plugins are baked into the signed image, so
in-dashboard core/plugin/theme edits and updates are disabled
(`DISALLOW_FILE_MODS`) — rebuild the image to change code. Auth salts are
generated once and persisted in the Secret, so upgrades don't log everyone out.

On a fresh install WordPress can't answer 2xx/3xx until MySQL is reachable (it
500s with "Error establishing a database connection"), so a startup probe
(`httpGet /`) tolerates the DB init window — up to 300s (30 x 10s) — before
liveness and readiness (both `httpGet /`) take over.

## Configuration examples

Bundled MySQL with a pinned site URL behind a proxy and a larger uploads volume:

```yaml
wordpress:
  siteUrl: https://blog.example.com
persistence:
  enabled: true
  size: 25Gi
mysql:
  enabled: true
  auth:
    rootPassword: "ChangeMeRoot"
    password: "ChangeMe"
networkPolicy:
  allowExternal: true
```

External MySQL/MariaDB with the password from an existing Secret (auth salts
still come from this chart's own Secret):

```yaml
mysql:
  enabled: false
externalDatabase:
  host: mysql.data.svc.cluster.local
  port: 3306
  database: wordpress
  user: wordpress
  existingSecret: my-db-credentials
  existingSecretPasswordKey: db-password
```

## Uninstall

```bash
helm uninstall blog
```

The uploads PVC (and the bundled MySQL's PVC) are retained by Kubernetes on
uninstall — delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=blog
```

## Notes

`/wp-admin` is password-protected, but the public site is meant for readers. By
default `networkPolicy.allowExternal` is `false`, restricting ingress to the
release namespace; front WordPress with an ingress/TLS proxy and set
`allowExternal=true` to expose it, and set `wordpress.siteUrl` so WordPress
builds correct absolute URLs behind the proxy. The chart depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`, and bundles the Quenchworks
MySQL chart when `mysql.enabled=true`. Every container runs as nonroot (uid
1001) on a read-only root filesystem, and the image is pinned by digest.
</content>

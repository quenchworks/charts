# Quenchworks phpMyAdmin

Hardened [phpMyAdmin](https://www.phpmyadmin.net/) — the web console for
MySQL and MariaDB — on a minimal, nonroot, read-only-rootfs 0-CVE image pinned
by digest and cosign-signed. It is served by a Wolfi **PHP-FPM + nginx** runtime
(supervisord): nginx listens on port 8080 (nonroot can't bind `<1024`) and
FastCGI-passes `.php` to php-fpm on `127.0.0.1:9000`. It runs as uid 1001.

phpMyAdmin is a **client**: it keeps no state of its own, so this chart is a
plain stateless `Deployment` with no PVC. Point it at the MySQL/MariaDB servers
you already run (`externalDatabase.host` or `phpmyadmin.hosts`), or flip
`mariadb.enabled=true` to bundle the Quenchworks MariaDB chart for a
self-contained install.

The chart supplies `config.inc.php` from a ConfigMap. That file reads every
setting — server list, port, auth type — from the pod environment at request
time, and takes the `blowfish_secret` (the key that signs and AES-encrypts the
cookie holding the user's database credentials) from a managed Secret. The
secret is **generated once and preserved across upgrades**, so a `helm upgrade`
does not log everyone out.

## Install

```bash
# point it at a database you already run
helm install pma oci://ghcr.io/quenchworks/charts/phpmyadmin \
  --set externalDatabase.host=mysql.data.svc.cluster.local
```

```bash
# or self-contained: bundle an in-cluster MariaDB
helm install pma oci://ghcr.io/quenchworks/charts/phpmyadmin \
  --set mariadb.enabled=true \
  --set mariadb.auth.rootPassword="ChangeMeRoot" \
  --set mariadb.auth.password="ChangeMe"
```

Reach the UI over a port-forward and log in with your **database** credentials
(cookie auth — nothing is stored server-side):

```bash
kubectl port-forward svc/pma-phpmyadmin 8080:8080
# http://localhost:8080/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/phpmyadmin \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/phpmyadmin \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/phpmyadmin` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless — scale freely; the shared `blowfish_secret` keeps sessions valid on any pod. |
| `phpmyadmin.hosts` | `""` | Comma-separated server list shown in the login dropdown. Empty uses the bundled MariaDB or `externalDatabase.host`. |
| `phpmyadmin.verboseNames` | `""` | Display names matching `hosts` (same order). |
| `phpmyadmin.authType` | `cookie` | `cookie` prompts for credentials; `config`/`http`/`signon` for the other upstream modes. |
| `phpmyadmin.absoluteUri` | `""` | Public URL when behind an ingress/TLS proxy (sets `PmaAbsoluteUri`). |
| `phpmyadmin.allowNoPassword` | `false` | Permit logins with an empty password. |
| `phpmyadmin.blowfishSecret` | `""` | 32-char cookie key. Empty: generated once, then preserved across upgrades. |
| `phpmyadmin.existingSecret` | `""` | Take the blowfish secret from an existing Secret instead. |
| `phpmyadmin.existingSecretBlowfishKey` | `blowfish-secret` | Key within that Secret. |
| `resources.requests` | `100m / 128Mi` | CPU / memory requests. |
| `resources.limits` | `1 / 512Mi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | The UI (nginx `http` port). |
| `mariadb.enabled` | `false` | Deploy the bundled Quenchworks MariaDB subchart and point phpMyAdmin at it. |
| `mariadb.auth.rootPassword` | `""` | Generated into MariaDB's own Secret if empty. |
| `mariadb.auth.database` | `phpmyadmin` | Database created on first init. |
| `mariadb.auth.username` | `phpmyadmin` | DB user created on first init. |
| `mariadb.auth.password` | `""` | Generated into MariaDB's own Secret if empty. |
| `externalDatabase.host` | `""` | Server to administer (when `mariadb.enabled=false`). |
| `externalDatabase.port` | `3306` | Server port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace; opens DNS + the DB port on egress. |
| `networkPolicy.allowExternal` | `false` | Set `true` **only** behind an authenticating ingress / VPN. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
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

A stateless **Deployment** runs the PHP-FPM + nginx runtime; nginx serves the
whole UI on container port 8080 and the Service maps the same port. There is no
PVC and no database of its own — all state belongs to the servers being
administered.

Two volumes are mounted because the root filesystem is read-only:

- **`/var/www/html/config.inc.php`** — the chart-supplied config, mounted
  read-only from a ConfigMap via `subPath` so it doesn't shadow the docroot. It
  resolves the server list, port, auth type and `blowfish_secret` from the pod
  environment at request time (php-fpm runs with `clear_env=no`).
- **`/tmp`** — a writable `emptyDir` for nginx pid/temp, PHP sessions and
  phpMyAdmin's `TempDir` (compiled Twig templates).

Liveness and readiness both `GET /`. That returns 200 as soon as nginx, php-fpm
and the PHP app are healthy and deliberately does **not** depend on a database
being up: phpMyAdmin's login page must stay servable while a target server is
down, which is exactly when you need it.

`blowfish_secret` is generated once and read back from the Secret via `lookup`
on every render, so upgrades preserve sessions. With `mariadb.enabled=true` the
subchart's primary Service (`<release>-mariadb`, port 3306) becomes the default
entry in the login dropdown.

## Configuration examples

Several servers in one console, behind an authenticating ingress:

```yaml
phpmyadmin:
  hosts: "mysql.data.svc.cluster.local,mariadb-report.data.svc.cluster.local"
  verboseNames: "Production MySQL,Reporting MariaDB"
  absoluteUri: https://pma.example.com/
networkPolicy:
  allowExternal: true
```

Self-contained demo with a bundled MariaDB:

```yaml
mariadb:
  enabled: true
  auth:
    rootPassword: "ChangeMeRoot"
    database: appdb
    username: appuser
    password: "ChangeMe"
```

Pin the cookie key from your own Secret (e.g. managed by an external secrets
operator):

```yaml
phpmyadmin:
  existingSecret: pma-cookie-key
  existingSecretBlowfishKey: blowfish-secret
```

## Uninstall

```bash
helm uninstall pma
```

Nothing of phpMyAdmin's survives — it stores nothing. A bundled MariaDB's PVC is
retained by Kubernetes; delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=pma
```

## Notes

phpMyAdmin is a full database administration surface: whoever reaches it can
attempt logins against your servers. `networkPolicy.allowExternal` is `false` by
default, restricting ingress to the release namespace — put it behind an
authenticating ingress or a VPN before exposing it, and set
`phpmyadmin.absoluteUri` so redirects are built correctly. The chart depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`, and bundles the Quenchworks
MariaDB chart when `mariadb.enabled=true`. Every container runs as nonroot (uid
1001) on a read-only root filesystem, and the image is pinned by digest.

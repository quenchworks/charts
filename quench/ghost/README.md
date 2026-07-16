# Quenchworks Ghost

Hardened [Ghost](https://ghost.org/), the Node.js publishing platform (CMS,
membership and newsletter engine), on a minimal, nonroot, 0-CVE image pinned by
digest and cosign-signed (keyless / Sigstore). Ghost runs as uid 1001 and serves
the public site and the `/ghost` admin on port 2368.

Ghost is configured entirely by environment variables (it reads `__`-nested
config keys, e.g. `database__connection__host`) and needs an external
MySQL/MariaDB. This chart bundles the Quenchworks MariaDB chart by default and
provisions a content PVC at `/var/lib/ghost/content` for themes, images, uploads,
data and logs. It can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster MariaDB + a content PVC
helm install blog oci://ghcr.io/quenchworks/charts/ghost \
  --set ghost.url="https://blog.example.com" \
  --set mariadb.auth.rootPassword="ChangeMeRoot" \
  --set mariadb.auth.password="ChangeMe"
```

`ghost.url` is required. Ghost derives every absolute link, canonical URL,
RSS/sitemap entry and admin redirect from it. The DB password is injected from a
managed Secret as `database__connection__password`, so it never appears in the
pod's process arguments.

Port-forward and open the site and admin:

```bash
kubectl port-forward svc/blog-ghost 2368:2368
# site:  http://localhost:2368/
# admin: http://localhost:2368/ghost/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ghost \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/ghost --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ghost` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single replica; the content PVC is ReadWriteOnce. |
| `ghost.url` | `http://localhost:2368` | Public site URL. Required; set to the address users actually reach Ghost at. |
| `resources.requests` | `250m / 512Mi` | CPU / memory requests. |
| `resources.limits` | `2 / 1Gi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `2368` | Public site + `/ghost` admin port. |
| `persistence.enabled` | `true` | Provision the content PVC. When `false`, uses an emptyDir. |
| `persistence.size` | `10Gi` | Content PVC size. |
| `persistence.mountPath` | `/var/lib/ghost/content` | Content mount path. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `mariadb.enabled` | `true` | Deploy the bundled MariaDB subchart. |
| `mariadb.auth.rootPassword` | `""` | Generated into MariaDB's own Secret if empty. |
| `mariadb.auth.database` | `ghost` | App database, created on first init. |
| `mariadb.auth.username` | `ghost` | DB user. |
| `mariadb.auth.password` | `""` | Generated into this chart's managed Secret if empty. |
| `mariadb.primary.persistence.size` | `8Gi` | MariaDB data volume size. |
| `externalDatabase.host` | `""` | External DB host (used when `mariadb.enabled=false`). |
| `externalDatabase.port` | `3306` | External DB port. |
| `externalDatabase.database` | `ghost` | External DB name. |
| `externalDatabase.user` | `ghost` | External DB user. |
| `externalDatabase.password` | `""` | External DB password (or use `existingSecret`). |
| `externalDatabase.existingSecret` | `""` | Secret carrying the password; no managed Secret is rendered. |
| `externalDatabase.existingSecretPasswordKey` | `db-password` | Password key in the existing Secret. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `containerSecurityContext.readOnlyRootFilesystem` | `false` | Relaxed for Ghost; see Architecture. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`, and the probe overrides
(`livenessProbe`, `readinessProbe`, and their
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe` replacements).

## Architecture

Ghost runs as a single-replica Deployment behind a ClusterIP Service on port 2368,
serving both the public site and the `/ghost` admin. All durable relational state
(posts, members, settings, users) lives in MariaDB; themes, images, uploaded files
and logs live on a ReadWriteOnce content PVC mounted at `/var/lib/ghost/content`.
It is a single replica because that PVC is ReadWriteOnce.

By default the bundled Quenchworks MariaDB subchart is deployed as a StatefulSet;
its primary Service is `<release>-mariadb` on port 3306. MariaDB creates
`mariadb.auth.database` and the `mariadb.auth.username`/`password` on first init,
and Ghost connects with them. To use an external MySQL/MariaDB, set
`mariadb.enabled=false` and fill in `externalDatabase.*` (or
`externalDatabase.existingSecret` carrying the password key).

First boot connects to MariaDB and runs all schema migrations before Ghost starts
serving, often 60 to 120 seconds on an empty DB. A startup probe (`GET /`, up to
300s grace) gates liveness and readiness so the slow boot is not killed
mid-migration; normal probe timing resumes once it passes.

The content PVC needs seeding. The Ghost image ships its default themes (the
active `source` theme) inside `/var/lib/ghost/content`, so mounting an empty PVC
over that path would hide them and Ghost would 500 with `active theme 'source' is
missing`. A `seed-content` initContainer runs the same Ghost image but mounts the
PVC at `/seed` instead, so the image's built-in content is not shadowed and it can
copy defaults onto the volume:

```sh
cp -an /var/lib/ghost/content/. /seed/ 2>/dev/null || true
```

`cp -an` is no-clobber, so existing user content is never overwritten on restarts;
only missing default files are added.

Ghost runs nonroot (uid 1001, fsGroup 1001 so the content PVC is writable). Its
Node process writes caches and locks under its app tree at runtime as well as the
content dir, so `containerSecurityContext.readOnlyRootFilesystem` is `false` for
this app; capabilities are still dropped. The `/ghost` admin is
password-protected, but the public site is meant for readers, so
`networkPolicy.allowExternal` defaults to `false`. Front Ghost with an ingress/TLS
proxy and set `allowExternal=true` to expose it.

## Configuration examples

Point at an external MySQL/MariaDB using an existing Secret for the password:

```yaml
mariadb:
  enabled: false
externalDatabase:
  host: mysql.db.svc.cluster.local
  port: 3306
  database: ghost
  user: ghost
  existingSecret: ghost-db
  existingSecretPasswordKey: db-password
```

Configure outbound mail (any `mail__*` key) via extra env vars, which are appended
after the chart's own env and win on conflict:

```yaml
extraEnvVars:
  - name: mail__transport
    value: SMTP
  - name: mail__options__host
    value: smtp.example.com
  - name: mail__options__port
    value: "587"
  - name: mail__options__auth__user
    value: apikey
  - name: mail__options__auth__pass
    valueFrom:
      secretKeyRef:
        name: ghost-smtp
        key: password
```

## Uninstall

```bash
helm uninstall blog
```

The content PVC and the MariaDB data volume are not removed automatically. The
content PVC (`<release>-ghost-content`) is deleted with the release only when it
was chart-provisioned; an `existingClaim` is left in place. The MariaDB
`volumeClaimTemplate` PVC is always retained. Delete leftover volumes explicitly
to remove the data:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=blog
```

## Notes

Single replica: the content PVC is ReadWriteOnce and Ghost stores durable state in
MariaDB, so this chart does not scale out. The chart depends on the `quench-common`
library chart and, by default, the bundled `mariadb` chart, both pulled from
`oci://ghcr.io/quenchworks/charts`. The image is pinned by digest and cosign-signed.

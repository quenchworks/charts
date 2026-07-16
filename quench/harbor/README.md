# Quenchworks Harbor

Hardened [Harbor](https://goharbor.io/), a cloud-native OCI registry with RBAC,
replication, vulnerability scanning and image signing, as a single umbrella chart
that wires nine minimal, nonroot, 0-CVE component images (pinned by digest) over
the Quenchworks PostgreSQL and Valkey charts. Every container runs as uid 1001 on
a read-only root filesystem with all capabilities dropped; each writable path is an
`emptyDir` (or a PVC for registry storage). The images are cosign-signed (keyless /
Sigstore) and the chart pins each one by its signed digest, never a tag. There is
no upstream "prepare" bootstrap container: the chart generates every credential
itself and persists it across upgrades.

## Components

| Component        | Role                                              | Optional |
|------------------|---------------------------------------------------|----------|
| core             | API, token service, `/v2` docker-protocol proxy   | no       |
| jobservice       | async jobs (GC, replication, scan, retention)     | no       |
| registry         | docker distribution (blob/manifest storage)       | no       |
| registryctl      | GC / quota controller (2nd container w/ registry) | no       |
| portal           | web UI (static SPA on nginx)                       | no       |
| proxy            | front-door nginx: `/` -> portal, API paths -> core | no       |
| trivy adapter    | vulnerability scanner (`trivy.enabled`)            | yes      |
| metrics exporter | Prometheus metrics (`metrics.enabled`)             | yes      |

A hardened busybox image supplies the wait-for-core initContainer (the Harbor
images carry no HTTP client). Backing services: PostgreSQL (one database,
`registry`; core auto-migrates the schema on boot) and Valkey (six logical redis
DBs multiplexed: core, registry, jobservice, cache-layer, trivy-store,
trivy-jobqueue). Both are bundled by default and can be swapped for external
instances. The Harbor CLI and content-trust/notary signing are out of scope for
this chart.

## Install

```bash
helm install reg oci://ghcr.io/quenchworks/charts/harbor
```

Self-contained: bundles in-cluster PostgreSQL and Valkey with deterministic
credentials, fronted by a Traefik Ingress on host `harbor.local`. Set the host and
external URL to your own:

```bash
helm install reg oci://ghcr.io/quenchworks/charts/harbor \
  --set ingress.host=harbor.example.com \
  --set externalURL=https://harbor.example.com
```

Turn on the optional scanner and metrics exporter:

```bash
helm install reg oci://ghcr.io/quenchworks/charts/harbor \
  --set trivy.enabled=true --set metrics.enabled=true
```

## Verify the image

Every component image is cosign-signed (keyless / Sigstore). Verify them all:

```bash
for img in harbor-core harbor-jobservice harbor-registry harbor-registryctl \
           harbor-portal harbor-trivy-adapter harbor-exporter nginx busybox; do
  cosign verify ghcr.io/quenchworks/images/$img \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

The bundled PostgreSQL and Valkey images are verified the same way (repos
`ghcr.io/quenchworks/images/postgresql` and `.../valkey`); they ship with their own
Quenchworks charts.

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI, for example:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/harbor-core \
  --owner quenchworks
```

## Values

Per-component images. Each `.digest` is the factory contract (CI rewrites it after
every green, scanned, signed build); the schema rejects tag-only references.

| Key | Default | Notes |
|-----|---------|-------|
| `images.pullPolicy` | `IfNotPresent` | Shared by all components. `Always`, `IfNotPresent`, or `Never`. |
| `images.core.{repository,digest}` | `ghcr.io/quenchworks/images/harbor-core` | API + token service. |
| `images.jobservice.{repository,digest}` | `.../harbor-jobservice` | Async job runner. |
| `images.registry.{repository,digest}` | `.../harbor-registry` | Docker distribution. |
| `images.registryctl.{repository,digest}` | `.../harbor-registryctl` | GC / quota controller. |
| `images.portal.{repository,digest}` | `.../harbor-portal` | Web UI. |
| `images.trivyAdapter.{repository,digest}` | `.../harbor-trivy-adapter` | Optional scanner. |
| `images.exporter.{repository,digest}` | `.../harbor-exporter` | Optional metrics exporter. |
| `images.proxy.{repository,digest}` | `.../nginx` | Front-door proxy. |
| `images.busybox.{repository,digest}` | `.../busybox` | wait-for-core initContainer. |

Global.

| Key | Default | Notes |
|-----|---------|-------|
| `nameOverride` | `""` | Override the chart name in resource names. |
| `logLevel` | `info` | Shared by all components: `debug`, `info`, `warning`, `error`, `fatal`. |
| `externalURL` | `""` | URL clients use to reach Harbor. Defaults to `http://<ingress.host>` when ingress is on. Must match the host you `docker login` to. |
| `auth.adminPassword` | `""` | Pin the `admin` password. Generated once (24 chars) and preserved across upgrades when empty. |

Component: proxy (front door).

| Key | Default | Notes |
|-----|---------|-------|
| `proxy.enabled` | `true` | Single nginx entry point. |
| `proxy.replicaCount` | `1` | |
| `proxy.service.type` | `ClusterIP` | |
| `proxy.service.port` | `80` | Maps to proxy container port 8080. |
| `proxy.resources` | `50m/64Mi` -> `500m/256Mi` | Requests -> limits. |

Component: core.

| Key | Default | Notes |
|-----|---------|-------|
| `core.replicaCount` | `1` | |
| `core.service.type` | `ClusterIP` | |
| `core.service.port` | `80` | |
| `core.resources` | `100m/256Mi` -> `2/1Gi` | Requests -> limits. |
| `core.csrfTrustedOrigins` | `[]` | Extra hosts trusted for the UI login CSRF check. Bare `host` or `host:port`, no scheme. The `externalURL` host is always trusted. |

Component: jobservice.

| Key | Default | Notes |
|-----|---------|-------|
| `jobservice.replicaCount` | `1` | |
| `jobservice.maxJobWorkers` | `10` | Concurrent job workers. |
| `jobservice.service.type` | `ClusterIP` | |
| `jobservice.service.port` | `8080` | |
| `jobservice.resources` | `100m/128Mi` -> `1/512Mi` | Requests -> limits. |

Component: registry (with registryctl as a second container).

| Key | Default | Notes |
|-----|---------|-------|
| `registry.replicaCount` | `1` | |
| `registry.service.type` | `ClusterIP` | |
| `registry.service.port` | `5000` | |
| `registry.resources` | `100m/128Mi` -> `1/1Gi` | Requests -> limits. |
| `registry.registryctl.service.type` | `ClusterIP` | |
| `registry.registryctl.service.port` | `8080` | |
| `registry.registryctl.resources` | `50m/64Mi` -> `500m/256Mi` | Requests -> limits. |

Component: portal.

| Key | Default | Notes |
|-----|---------|-------|
| `portal.replicaCount` | `1` | |
| `portal.service.type` | `ClusterIP` | |
| `portal.service.port` | `80` | |
| `portal.resources` | `50m/64Mi` -> `500m/256Mi` | Requests -> limits. |

Component: trivy scan adapter (optional).

| Key | Default | Notes |
|-----|---------|-------|
| `trivy.enabled` | `false` | Register the adapter as core's default scanner. |
| `trivy.debugMode` | `false` | |
| `trivy.insecure` | `false` | Skip TLS verification to the registry. |
| `trivy.ignoreUnfixed` | `false` | Report only fixable vulnerabilities. |
| `trivy.skipUpdate` | `false` | Skip the Trivy DB download. |
| `trivy.offlineScan` | `false` | |
| `trivy.securityCheck` | `vuln` | Scan categories. |
| `trivy.dbRepository` | `ghcr.io/aquasecurity/trivy-db` | Trivy DB OCI source, pulled at runtime. |
| `trivy.service.{type,port}` | `ClusterIP` / `8080` | |
| `trivy.persistence.enabled` | `false` | Cache PVC (DB + reports); `emptyDir` when false. |
| `trivy.persistence.size` | `5Gi` | |
| `trivy.persistence.storageClass` | `""` | |
| `trivy.persistence.accessModes` | `["ReadWriteOnce"]` | |
| `trivy.resources` | `100m/256Mi` -> `1/1Gi` | Requests -> limits. |

Component: metrics exporter (optional).

| Key | Default | Notes |
|-----|---------|-------|
| `metrics.enabled` | `false` | Deploy the exporter; core/registry/jobservice expose their own `/metrics` too. |
| `metrics.exporter.service.{type,port}` | `ClusterIP` / `8001` | |
| `metrics.exporter.resources` | `50m/64Mi` -> `500m/256Mi` | Requests -> limits. |
| `metrics.core.{path,port}` | `/metrics` / `8001` | |
| `metrics.registry.{path,port}` | `/metrics` / `8001` | |
| `metrics.jobservice.{path,port}` | `/metrics` / `8001` | |

Database (PostgreSQL).

| Key | Default | Notes |
|-----|---------|-------|
| `postgresql.enabled` | `true` | Bundle the in-cluster PostgreSQL subchart. |
| `postgresql.auth.username` | `harbor` | |
| `postgresql.auth.password` | `harbor` | |
| `postgresql.auth.database` | `registry` | Core auto-migrates the schema on boot. |
| `postgresql.primary.persistence.{enabled,size}` | `true` / `8Gi` | |
| `externalDatabase.host` | `""` | Used when `postgresql.enabled=false`. |
| `externalDatabase.port` | `5432` | |
| `externalDatabase.user` | `harbor` | |
| `externalDatabase.password` | `""` | Or set `existingSecret`. |
| `externalDatabase.database` | `registry` | Must already exist. |
| `externalDatabase.sslmode` | `disable` | |
| `externalDatabase.existingSecret` | `""` | |
| `externalDatabase.existingSecretPasswordKey` | `password` | |

Cache (Valkey).

| Key | Default | Notes |
|-----|---------|-------|
| `valkey.enabled` | `true` | Bundle the in-cluster Valkey subchart. |
| `valkey.auth.enabled` | `true` | |
| `valkey.auth.password` | `harbor-valkey` | |
| `valkey.primary.persistence.{enabled,size}` | `true` / `8Gi` | |
| `externalCache.host` | `""` | Used when `valkey.enabled=false`. |
| `externalCache.port` | `6379` | |
| `externalCache.password` | `""` | |
| `externalCache.existingSecret` | `""` | |
| `externalCache.existingSecretPasswordKey` | `redis-password` | |
| `redisDB.{core,registry,jobservice,cacheLayer,trivyStore,trivyJobQueue}` | `0`/`1`/`2`/`3`/`4`/`5` | Logical DB indexes on the shared Valkey. Rarely changed. |

Storage, ingress, and cluster knobs.

| Key | Default | Notes |
|-----|---------|-------|
| `persistence.enabled` | `true` | Registry storage PVC mounted at `/storage`. `emptyDir` when false. |
| `persistence.size` | `50Gi` | |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | |
| `ingress.enabled` | `true` | Traefik Ingress in front of the proxy Service. |
| `ingress.className` | `traefik` | |
| `ingress.host` | `harbor.local` | Derives `externalURL` when that is unset. |
| `ingress.annotations` | `{}` | |
| `ingress.tls.enabled` | `false` | |
| `ingress.tls.secretName` | `""` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `serviceAccount.annotations` | `{}` | |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | |
| `networkPolicy.allowExternal` | `true` | Allow ingress to portal/core from outside the release namespace; backend components stay restricted. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs applied to every component: `podLabels`,
`podAnnotations`, `nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `priorityClassName`, `schedulerName`,
`terminationGracePeriodSeconds`, `podSecurityContext`, and
`containerSecurityContext` (both merge over the hardened defaults, your keys win).

## Architecture

The whole app is reachable through one Service, the `proxy` (an nginx front door,
`proxy.enabled`, default true). It routes `/` to the portal (UI) and `/api`,
`/service`, `/v2`, `/c`, `/chartrepo` to core. Its Service is named after the
release (e.g. `reg-harbor`) and maps port 80 to proxy 8080. A Traefik Ingress
(`ingress.enabled`, default true) sits in front of that Service; `ingress.host`
derives `externalURL` when it is unset. With no ingress, `externalURL` defaults to
the in-cluster proxy Service URL. When `proxy.enabled=false` the chart fronts
core/portal directly (set `ingress.enabled=false` and an explicit `externalURL`).

The token service is the trust anchor. The chart generates an RSA keypair, gives
the private key to core (it signs registry-auth bearer tokens) and core validates
them at `/service/token`. This is separate from internal TLS, which is disabled for
in-cluster plaintext traffic. `externalURL` (or the ingress host) must match the
host you `docker login` to, or token-audience checks reject pulls and pushes.

core is the API, token service, and public face of the registry for `/v2`. registry
holds the actual blobs and manifests, with registryctl as a second container for GC
and quota. jobservice runs async work (GC, replication, scan, retention) and waits
on core readiness through a busybox initContainer before booting. portal serves the
static UI. All of them share one PostgreSQL database (`registry`, schema
auto-migrated by core) and one Valkey, on which Harbor multiplexes six logical redis
DBs by index (`redisDB.*`). Registry blob storage is a PVC mounted at `/storage`
(`persistence.enabled`, default 50Gi); for ephemeral installs an `emptyDir` is used.

`replicaCount` stays at 1 per component: the bundled PostgreSQL/Valkey and the
shared registry storage are single-writer, so HA is a future capability.

## Configuration examples

Admin login. User is always `admin`; read the generated password:

```bash
kubectl get secret reg-harbor -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d ; echo
```

docker login and push/pull (host must match `externalURL`):

```bash
docker login harbor.example.com           # admin + the password above
docker tag alpine harbor.example.com/library/alpine
docker push harbor.example.com/library/alpine
docker pull harbor.example.com/library/alpine
```

Reach Harbor over a port-forward. Forward the proxy Service, and trust the
port-forward host for the UI login CSRF check:

```bash
helm upgrade reg oci://ghcr.io/quenchworks/charts/harbor --reuse-values \
  --set core.csrfTrustedOrigins[0]=127.0.0.1:8080
kubectl port-forward svc/reg-harbor 8080:80   # then open http://127.0.0.1:8080/
```

Enable the Trivy scanner. Core registers the adapter as the default scanner
(`WITH_TRIVY=true`); the adapter downloads the Trivy DB at runtime:

```bash
helm upgrade reg oci://ghcr.io/quenchworks/charts/harbor --reuse-values \
  --set trivy.enabled=true
```

Enable metrics. The exporter serves `:8001/metrics`; core/registry/jobservice
expose their own metrics ports too:

```bash
helm upgrade reg oci://ghcr.io/quenchworks/charts/harbor --reuse-values \
  --set metrics.enabled=true
```

Use external PostgreSQL and Valkey instead of the bundled ones:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.com
  user: harbor
  password: <pw>          # or set existingSecret
  database: registry      # must already exist; core migrates the schema
valkey:
  enabled: false
externalCache:
  host: redis.example.com
  password: <pw>
```

Ephemeral test install (no PVCs):

```yaml
persistence:
  enabled: false
postgresql:
  primary:
    persistence:
      enabled: false
```

## Uninstall

```bash
helm uninstall reg
```

PVCs (registry storage, and the bundled PostgreSQL/Valkey volumes) are retained by
Kubernetes on uninstall. Delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=reg
```

## Notes

The chart depends on the `quench-common` library chart and the Quenchworks
`postgresql` and `valkey` charts, all pulled from
`oci://ghcr.io/quenchworks/charts`. Every container runs as uid 1001 on a read-only
root filesystem with all capabilities dropped, and each image is pinned by digest.
`externalURL` (or the ingress host) must match the host clients log in to, or the
token service rejects pulls and pushes. The Harbor CLI and content-trust/notary
signing are out of scope.

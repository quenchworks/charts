# QuenchWorks charts

**English** · [العربية](README.ar.md) · [Español](README.es.md)

<p align="center">
  <a href="https://quench-works.com/images"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/images.json" alt="images"></a>
  <a href="https://quench-works.com/charts"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/charts.json" alt="charts"></a>
  <a href="https://quench-works.com/security"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/cves.json" alt="open CVEs"></a>
  <a href="https://github.com/wolfi-dev"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/wolfi.json" alt="built from source"></a>
  <a href="https://docs.sigstore.dev/"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/cosign.json" alt="signed with cosign"></a>
  <a href="https://quench-works.com/images"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/multiarch.json" alt="multi-arch"></a>
  <a href="https://artifacthub.io/packages/search?org=quenchworks"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/artifacthub.json" alt="ArtifactHub"></a>
  <a href="https://github.com/quenchworks"><img src="https://img.shields.io/endpoint?url=https://quench-works.com/api/v1/badge/license.json" alt="license"></a>
</p>

Clean-room Helm charts for the [QuenchWorks](https://github.com/quenchworks) catalog. Every chart deploys a hardened, 0-CVE image from the [images](https://quench-works.com/images) factory, pins it strictly by `sha256` digest, ships as a cosign-signed OCI artifact on GHCR, and is listed on ArtifactHub as a **verified publisher** with a Values schema.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks in a terminal: run a 0-CVE image, verify it with cosign, deploy the Helm chart, and watch the pod reach Running." width="760"></a>
</p>

**50+ charts.** No paywall, no account, no vendor lock. Browse them all at [quench-works.com/charts](https://quench-works.com/charts).

```bash
helm install cache oci://ghcr.io/quenchworks/charts/redis
```

That's the whole install. The image it deploys is already signed and pinned to a digest, so you don't have to track image security yourself.

## The security model

Three guarantees, baked into every chart:

- **Digest-pinned, always.** Charts resolve images by `repository@sha256:...`, never by tag. A tag-only reference is refused on purpose, so a chart physically can't ship an unpinned image.
- **One hardened baseline.** Every chart inherits the same pod and container security context from the [`quench-common`](https://github.com/quenchworks/common) library chart: nonroot, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp `RuntimeDefault`. Fix it once, fix it everywhere.
- **Verifiable provenance.** Charts are cosign keyless-signed, and the images they point at are signed and SBOM-carrying. You can check it all yourself.

## Shared objects and opt-in Ingress

Five families of manifest that were near-identical in every chart render from the
[`quench-common`](https://github.com/quenchworks/common) library rather than from a
copy in each chart: `ServiceAccount`, RBAC (`Role`/`RoleBinding`, optionally
cluster-scoped), `PodDisruptionBudget`, `HorizontalPodAutoscaler` and `NetworkPolicy`.
Fix one, fix the catalog.

Which families moved was decided by measurement, not taste — grouping all 138 charts
by rendered shape: `serviceaccount.yaml` 117/132 identical, `poddisruptionbudget.yaml`
105/123, `rbac.yaml` 104/123, `hpa.yaml` 20/23. The `NetworkPolicy` is shared but
**parameterised**, because 128 charts produced 91 distinct shapes — every app allows
different ports. `service.yaml` deliberately stays per-chart: 98 distinct shapes from
128 charts, since the port list is the application's identity and a helper would need
as much configuration as the manifest it replaced.

Every chart that serves HTTP has an **Ingress, disabled by default**:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com      # a host with no `paths` gets one "/" Prefix path
  tls:
    - hosts: [app.example.com]
      secretName: app-tls
```

The backend port is resolved from whichever service shape the chart uses, so a host is
usually all you need. Enabling it with no host, or where no HTTP port can be resolved,
fails the template with an explanation instead of installing something that routes
nowhere.

Charts that do **not** speak HTTP — PostgreSQL, Redis, Kafka, MariaDB, etcd — have no
`ingress` knob at all. An `Ingress` is an HTTP router and cannot front them; expose
those with `service.type=LoadBalancer` or your controller's TCP passthrough. A flag
that silently did nothing would be worse than no flag.

The umbrella **stacks** have no Service of their own, so their `ingress` fronts a
subchart Service — the stack's primary UI by default (Grafana, or Keycloak for
`identity-stack`) — and `ingress.serviceName` / `ingress.servicePort` point it at any
other component. You can equally leave it off and enable the subchart's own ingress,
e.g. `grafana.ingress.enabled=true`.

Alongside those, every chart exposes `commonLabels`, `commonAnnotations` and
`podLabels` (all safe to change on a live release), plus `partOf`, `fullnameOverride`,
`image.registry` and `imagePullSecrets`. `selectorLabels` exists too, but it feeds
`spec.selector`, which Kubernetes treats as **immutable** — set it before the first
install or every later `helm upgrade` fails with `field is immutable`.

## The catalog

| Category | Charts |
|----------|--------|
| Relational | `postgresql` · `mariadb` · `mysql` · `cockroachdb` ⚠️ |
| Document | `couchdb` · `ferretdb` · `documentdb` · `postgres-documentdb` · `mongodb` ⚠️ |
| Wide-column | `cassandra` · `scylladb` |
| Key-value / cache | `valkey` · `redis` · `memcached` · `dragonfly` ⚠️ |
| Search / vector | `opensearch` · `solr` · `meilisearch` · `qdrant` · `elasticsearch` ⚠️ |
| Time series | `influxdb` · `victoriametrics` |
| Analytical | `clickhouse` |
| Graph | `neo4j` |
| Messaging / streaming | `kafka` · `nats` · `rabbitmq` · `pulsar` |
| Coordination | `etcd` · `zookeeper` · `temporal` |
| Observability | `prometheus` · `grafana` · `loki` · `tempo` · `otel-collector` · `vector` · `fluent-bit` |
| Gateways / proxies | `nginx` · `caddy` · `traefik` · `haproxy` |
| Object storage | `garage` · `rustfs` · `seaweedfs` |
| Secrets / identity | `openbao` · `keycloak` |
| Registry · Git · CI/IaC | `harbor` · `gitea` · `atlantis` |

⚠️ = source-available, **not** OSI-approved open source (see [licensing](#a-note-on-licensing)).

## Verify a chart

```bash
cosign verify ghcr.io/quenchworks/charts/postgresql@sha256:DIGEST \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Per-chart docs

GitHub shows this single repo README on every chart's package page; it can't render a per-chart README for OCI artifacts. Each chart's own docs (values, examples, security notes) live on **ArtifactHub** and ship inside the chart itself:

```bash
helm show readme oci://ghcr.io/quenchworks/charts/<chart>
```

## Layout

```
quench/<app>/             one app chart per directory, e.g. quench/postgresql
.github/workflows/        release (lint, install, package, push) and digest repin
```

The shared `quench-common` library chart lives in its own repo, [quenchworks/common](https://github.com/quenchworks/common), published at `oci://ghcr.io/quenchworks/charts/quench-common`. App charts depend on it and pull it at build time, so it isn't vendored here.

## How releases work

The image factory builds and signs an image, then fires an `image-published` dispatch to this repo. `on-digest.yml` repins the chart's `values.yaml` to the new digest and commits. That push triggers `release-<app>.yml`, which lints, templates, installs into a kind cluster and runs a real client roundtrip as a gate, then packages and pushes the cosign-signed OCI chart and publishes the ArtifactHub metadata.

## The clean-room rule

Charts here are written from each application's own upstream documentation. They are not copied or adapted from any other vendor's charts. See [CONTRIBUTING](https://github.com/quenchworks/.github/blob/main/CONTRIBUTING.md).

## A note on licensing

Most of the catalog is OSI-clean. Four charts wrap source-available datastores and carry a loud license banner in their README, NOTES, and on the website, because these are **not** OSI-approved open source. Each names the clean alternative we recommend instead:

| Chart | License | Clean alternative |
|-------|---------|-------------------|
| `mongodb` | SSPL-1.0 | `ferretdb` + `documentdb` (MongoDB-wire compatible, truly open) |
| `elasticsearch` | SSPL-1.0 | `opensearch` (Apache-2.0 drop-in fork) |
| `cockroachdb` | BUSL-1.1 | `postgresql` for single-region SQL (BUSL converts to Apache after 3 years) |
| `dragonfly` | BUSL-1.1 | `valkey` (BSD-3-Clause, Redis-compatible) |

## License

MIT for the chart templates and tooling. Each deployed application carries its own upstream license.

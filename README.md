# Quenchworks charts

Clean-room Helm charts for the [Quenchworks](https://github.com/quenchworks) catalog. Each chart
pins its image by `sha256` digest to a signed, 0-CVE image from the
[images](https://github.com/quenchworks/images) factory, is published as an OCI artifact to GHCR,
and is listed on ArtifactHub as a verified publisher with a Values schema.

Browse the catalog at [quenchworks.mkabumattar.com/charts](https://quenchworks.mkabumattar.com/charts).

> **Per-chart docs:** GitHub shows this one repo README on every chart's package page; it can't
> show a per-chart README for OCI artifacts. Each chart's own README (values, examples, security
> notes) renders on **ArtifactHub** and ships inside the chart, run `helm show readme oci://ghcr.io/quenchworks/charts/<chart>`.

## Charts

**28 charts**, one per datastore. Every chart pins its image by digest, runs nonroot on a read-only
root filesystem, and shares the `quench-common` knob surface (scheduling, probes, extra
env/volumes/sidecars, security contexts). Install any of them with
`helm install <name> oci://ghcr.io/quenchworks/charts/<chart>`.

| Category | Charts |
|----------|--------|
| Relational | `postgresql` · `mariadb` · `mysql` · `cockroachdb` ⚠️ |
| Document | `couchdb` · `ferretdb` · `documentdb` · `postgres-documentdb` · `mongodb` ⚠️ |
| Wide-column | `cassandra` · `scylladb` |
| Key-value / cache | `valkey` · `redis` · `memcached` · `dragonfly` ⚠️ |
| Search | `opensearch` · `solr` · `elasticsearch` ⚠️ |
| Time series | `influxdb` · `victoriametrics` |
| Analytical | `clickhouse` |
| Graph | `neo4j` |
| Messaging | `kafka` · `nats` · `rabbitmq` · `pulsar` |
| Coordination | `etcd` · `zookeeper` |

⚠️ = source-available, **not** OSI-approved open source (see "A note on licensing" below).

## Install a chart

```bash
helm install my-postgresql oci://ghcr.io/quenchworks/charts/postgresql
```

Each image the charts deploy is signed and pinned by digest, so you do not have to track it
yourself. To verify a chart:

```bash
cosign verify ghcr.io/quenchworks/charts/postgresql@sha256:DIGEST \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Layout

```
quench/<app>/             one app chart per directory, e.g. quench/postgresql
.github/workflows/        release (lint, install, package, push) and digest repin
```

> The shared `quench-common` library chart lives in its own repo,
> [quenchworks/common](https://github.com/quenchworks/common), and is published as an OCI artifact at
> `oci://ghcr.io/quenchworks/charts/quench-common`. App charts depend on it via
> `repository: oci://ghcr.io/quenchworks/charts` and pull it at build time, so it is not vendored
> in this repo.

## How releases work

The image factory builds and signs an image, then sends an `image-published` dispatch to this repo.
`on-digest.yml` repins the chart's `values.yaml` to the new digest and commits. The push triggers
`release-<app>.yml`, which lints, templates, installs into a kind cluster and runs a real
client roundtrip as a gate, then packages and pushes the cosign-signed OCI chart and publishes the
ArtifactHub metadata.

## The clean-room rule

Charts here are written from each application's own upstream documentation. They are not copied or
adapted from any other vendor's charts. See
[CONTRIBUTING](https://github.com/quenchworks/.github/blob/main/CONTRIBUTING.md).

## A note on licensing

Most of the catalog is OSI-clean. Four charts wrap source-available datastores and carry a loud
license banner in their README, NOTES, and on the website, because these are **not** OSI-approved
open source. Each names the clean alternative we recommend instead:

| Chart | License | Clean alternative |
|-------|---------|-------------------|
| `mongodb` | SSPL-1.0 | `ferretdb` + `documentdb` (MongoDB-wire compatible, truly open) |
| `elasticsearch` | SSPL-1.0 | `opensearch` (Apache-2.0 drop-in fork) |
| `cockroachdb` | BSL-1.1 | `postgresql` for single-region SQL (BSL converts to Apache after 3 years) |
| `dragonfly` | BSL-1.1 | `valkey` (BSD-3-Clause, Redis-compatible) |

## License

MIT for the chart templates and tooling. Each deployed application carries its own upstream license.

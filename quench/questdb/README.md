# Quenchworks QuestDB

Hardened [QuestDB](https://questdb.io) on a minimal, nonroot, 0-CVE image pinned
by digest. QuestDB is a high-performance time-series SQL database with three
ingestion/query interfaces: an HTTP REST API + web console, the PostgreSQL wire
protocol, and the InfluxDB line protocol (ILP).

## Install

```bash
helm install my-questdb oci://ghcr.io/quenchworks/charts/questdb
```

## Standalone

QuestDB open source is **standalone** — a single node with its own storage.
Replication and high availability are QuestDB Enterprise features, so this chart
runs one replica with one PVC (`replicaCount` stays `1`; raising it would create
independent databases, not a cluster). A pod or node loss is downtime until the
StatefulSet reschedules and reattaches the PVC.

## Ports

| Port   | Protocol        | Use                                                                 |
| ------ | --------------- | ------------------------------------------------------------------- |
| `9000` | HTTP            | Web console + REST API (`/exec`, `/imp`); also InfluxDB HTTP ingest |
| `8812` | PostgreSQL wire | Query with any Postgres client (`psql`, JDBC, drivers)              |
| `9009` | ILP (TCP)       | InfluxDB line protocol, high-throughput ingest                      |

A dedicated health server on `9003` (`/status`) backs the liveness/readiness
probes; it is not exposed through the Service.

## Connect

### Web console / REST

```bash
kubectl port-forward svc/my-questdb 9000:9000
# browse http://127.0.0.1:9000, or:
curl -G http://127.0.0.1:9000/exec --data-urlencode "query=SELECT 1"
```

### PostgreSQL wire (psql)

Default credentials are `admin` / `quest`.

```bash
kubectl port-forward svc/my-questdb 8812:8812
PGPASSWORD=quest psql -h 127.0.0.1 -p 8812 -U admin -d qdb -c "SELECT build();"
```

## Persistence

The data directory (`QDB_ROOT`, `/var/lib/questdb`: `db`, WAL, config, logs) is a
`volumeClaimTemplate` PVC (`persistence.size`, default `8Gi`). Set
`persistence.enabled=false` for an ephemeral `emptyDir` (dev/test only), or
`persistence.existingClaim` to bind a pre-provisioned PVC.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/questdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/questdb --owner quenchworks
```

## Values

| Key                           | Default                              | Notes                                                                                     |
| ----------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------- | ----------- |
| `image.repository`            | `ghcr.io/quenchworks/images/questdb` |                                                                                           |
| `image.digest`                | (CI-written)                         | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                  | Standalone. QuestDB OSS is single-node.                                                   |
| `persistence.enabled`         | `true`                               | 8Gi PVC at `/var/lib/questdb`.                                                            |
| `persistence.size`            | `8Gi`                                |                                                                                           |
| `service.httpPort`            | `9000`                               | Web console + REST.                                                                       |
| `service.pgPort`              | `8812`                               | PostgreSQL wire protocol.                                                                 |
| `service.ilpPort`             | `9009`                               | InfluxDB line protocol.                                                                   |
| `extraJavaOpts`               | `""`                                 | Extra JVM flags, e.g. `-Xmx4g`.                                                           |
| `serviceAccount.create`       | `true`                               | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                              | Minimal Role/RoleBinding.                                                                 |
| `networkPolicy.enabled`       | `true`                               | Ingress to the three ports from the namespace.                                            |
| `podDisruptionBudget.enabled` | `true`                               | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                              | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                 | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                 | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                               | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                 | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                 | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/var/lib/questdb` data volume and `/tmp` are writable.

## Notes

QuestDB ships with default PostgreSQL-wire credentials (`admin`/`quest`) and no
REST auth. For anything beyond a trusted namespace, set credentials and enable
auth via `QDB_*` settings through `extraEnvVars`, and keep `networkPolicy`
restricting ingress.

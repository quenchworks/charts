# AKHQ

[AKHQ](https://akhq.io) is a web UI for Apache Kafka: browse and produce messages, and
manage topics, consumer groups, the schema registry, Kafka Connect and ACLs, across
one or more clusters. This chart runs it on the QuenchWorks akhq image. The image is
nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install akhq oci://ghcr.io/quenchworks/charts/akhq \
  --set 'connections.local.properties.bootstrap\.servers=kafka.data.svc:9092'
kubectl port-forward svc/akhq 8080:8080
# open http://127.0.0.1:8080/ui
```

## Clusters

`connections` is AKHQ's `akhq.connections` map: per cluster, the Kafka client
`properties` and optionally a `schema-registry` and `connect` list (see values.yaml).
The chart renders the whole `application.yml` into a Secret, since those properties
often hold SASL passwords. Bring your own with `existingSecret` (key `application.yml`).

Other AKHQ settings (`security`, `ui-options`, topic defaults) go in `akhqConfig`,
merged under `akhq:`.

## Security

AKHQ has no login by default: anyone who reaches the UI can read and write topics. Keep
the Service internal, or configure `akhqConfig.security` (basic auth, LDAP or OIDC).

## Values

| Key | Default | Meaning |
|---|---|---|
| `connections` | `{}` | Kafka clusters; with none, the pod stays unready |
| `akhqConfig` | `{}` | other `akhq:` settings |
| `existingSecret` | `""` | a Secret with a full `application.yml` |
| `javaOpts` | `-XX:MaxRAMPercentage=75` | JVM flags |
| `service.port` | `8080` | UI port |

Pods run with a read-only root filesystem and all capabilities dropped. Health is on
28081 (`/health`), which readiness uses.

The release gate installs the QuenchWorks kafka chart as a one-broker cluster, creates a
topic, installs this chart against it, and requires AKHQ to report healthy, serve the UI
and list the topic through its API.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

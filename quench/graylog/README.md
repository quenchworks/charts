# Quenchworks Graylog

Hardened [Graylog](https://graylog.org/), the log management and SIEM server, on a
minimal, nonroot, 0-CVE image pinned by digest and cosign-signed (keyless /
Sigstore). Graylog runs as uid 1001 and serves the web UI and REST API on port
9000. The chart pins the image by its signed digest, never a tag.

> License notice: SSPL-1.0. Graylog Server is licensed under the Server Side
> Public License v1, which is source-available, not OSI-approved open source. The
> Open Source Initiative has declined to approve the SSPL, so review the license
> (in particular its service and hosting conditions) before running Graylog in
> production or offering it as a service. This chart and the underlying image are
> Quenchworks-authored (clean-room); only the upstream Graylog artifact carries
> the SSPL terms.

Graylog is configured entirely by environment variables (each config key maps to a
`GRAYLOG_<KEY>` var) and needs two backends: MongoDB for configuration and metadata
(users, streams, dashboards, inputs), and OpenSearch (or Elasticsearch) for the
indexed log message storage. This chart bundles the Quenchworks MongoDB and
OpenSearch charts by default and provisions a small data PVC at `/var/lib/graylog`
for the rendered `server.conf`, node-id and message journal. It can also point at
external backends.

## Install

```bash
# self-contained: bundles in-cluster MongoDB + OpenSearch + a data PVC
helm install logs oci://ghcr.io/quenchworks/charts/graylog \
  --set graylog.externalUri="https://graylog.example.com/" \
  --set graylog.adminPassword="ChangeMeAdmin" \
  --set mongodb.auth.rootPassword="ChangeMeRoot"
```

`graylog.externalUri` is required: the web UI's asset/API base and redirects derive
from it, and it must end with a trailing slash. `graylog.adminPassword` is required
too; you log into the web UI with `graylog.adminUsername` (default `admin`) and this
password. The plaintext is never stored, only its sha256
(`GRAYLOG_ROOT_PASSWORD_SHA2`) is rendered into a managed Secret. Set
`mongodb.auth.rootPassword` for a deterministic install; left empty it is generated
and shared with Graylog's connection URI via `lookup`.

Reach the UI over a port-forward:

```bash
kubectl port-forward svc/logs-graylog 9000:9000
# UI + API: http://localhost:9000/  (login: admin / your graylog.adminPassword)
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/graylog \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/graylog --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/graylog` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single replica; the data PVC is ReadWriteOnce. |
| `graylog.externalUri` | `http://localhost:9000/` | Required. Public URI (`GRAYLOG_HTTP_EXTERNAL_URI`); must end with a trailing slash. |
| `graylog.bindAddress` | `0.0.0.0:9000` | In-pod bind address (`GRAYLOG_HTTP_BIND_ADDRESS`). |
| `graylog.adminUsername` | `admin` | Built-in root account (`GRAYLOG_ROOT_USERNAME`). |
| `graylog.adminPassword` | `""` | Required. Plaintext admin password; only its sha256 is stored. |
| `graylog.passwordSecret` | `""` | Secret for stored credentials (>= 16 chars). Generated and reused via `lookup` if empty. |
| `graylog.mongodbDatabase` | `graylog` | MongoDB database name. |
| `graylog.serverJavaOpts` | `""` | Override JVM opts (image bakes `-Xms1g -Xmx1g`). |
| `resources.requests` | `cpu 500m / mem 1536Mi` | |
| `resources.limits` | `cpu 2 / mem 2Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `9000` | Web UI + REST API. |
| `service.inputs` | `[]` | Extra message-input ports; added to the Service, container ports, and NetworkPolicy. |
| `persistence.enabled` | `true` | Data PVC at `/var/lib/graylog`. |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.mountPath` | `/var/lib/graylog` | Where the PVC mounts. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `mongodb.enabled` | `true` | Deploy the bundled MongoDB backend. |
| `mongodb.auth.rootUsername` | `root` | |
| `mongodb.auth.rootPassword` | `""` | Shared with Graylog's URI; set for a deterministic install. |
| `opensearch.enabled` | `true` | Deploy the bundled OpenSearch backend. |
| `externalMongodb.uri` | `""` | External MongoDB URI (when `mongodb.enabled=false`). |
| `externalMongodb.existingSecret` | `""` | Secret carrying the URI instead of `uri`. |
| `externalMongodb.existingSecretUriKey` | `mongodb-uri` | Key within that Secret. |
| `externalOpensearch.hosts` | `""` | Comma-separated hosts (when `opensearch.enabled=false`). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Graylog runs as a single-replica Deployment behind a ClusterIP Service; the bundled
MongoDB and OpenSearch run as StatefulSets via their subcharts. The replica count
stays at 1 because the data PVC is ReadWriteOnce.

MongoDB holds config and metadata. The bundled subchart's primary Service is
`<release>-mongodb` on port 27017. Graylog connects as the root user against the
`admin` authSource, using database `graylog.mongodbDatabase` (default `graylog`).
The chart builds the full `mongodb://` URI, with the resolved root password, into
its managed Secret and injects it as `GRAYLOG_MONGODB_URI`, so it never appears in
the pod's process arguments. For an external MongoDB, set `mongodb.enabled=false`
and provide `externalMongodb.uri` (or `externalMongodb.existingSecret` carrying the
URI key).

OpenSearch holds the log storage. The bundled subchart's Service is
`<release>-opensearch` on port 9200, with the security plugin disabled for internal
use, so Graylog reaches it over plain http with no auth
(`GRAYLOG_ELASTICSEARCH_HOSTS`). For an external cluster, set
`opensearch.enabled=false` and provide `externalOpensearch.hosts` (comma-separated,
credentials embedded in the URI if required).

First boot is slow: the JVM starts, connects to both backends, then initialises the
schema and indices before serving, often 60-180s. A startup probe hits
`/api/system/lbstatus` until it reports ALIVE (up to 600s grace, 60 x 10s), so the
slow boot is not killed; normal probe timing resumes after it passes. The pod runs
nonroot (uid 1001) on a read-only root filesystem, so writes go only to the data PVC
at `/var/lib/graylog` and a `/tmp` emptyDir. The web UI and API are authenticated,
but with `networkPolicy.allowExternal=false` (default) ingress is restricted to the
release namespace. Egress opens MongoDB (27017), OpenSearch (9200) and DNS, plus
general egress (Graylog fetches GeoIP/marketplace content and sends notifications).

## Configuration examples

Message inputs (GELF, Syslog, Beats) are created at runtime in the UI. To let their
traffic reach the pod, declare their ports under `service.inputs`; each entry is
added to the Service, the container ports and the NetworkPolicy ingress:

```yaml
service:
  inputs:
    - { name: gelf-tcp, port: 12201, protocol: TCP }
    - { name: syslog-udp, port: 1514, protocol: UDP }
```

Bring your own MongoDB and OpenSearch:

```yaml
mongodb:
  enabled: false
opensearch:
  enabled: false
externalMongodb:
  uri: "mongodb://user:pass@mongo:27017/graylog?authSource=admin"
externalOpensearch:
  hosts: "http://os-1:9200,http://os-2:9200"
```

Shrink the JVM heap for a small cluster and add extra `GRAYLOG_<KEY>` settings:

```yaml
graylog:
  serverJavaOpts: "-Xms512m -Xmx512m -server -XX:+UseG1GC"
extraEnvVars:
  - { name: GRAYLOG_TIMEZONE, value: "UTC" }
```

Expose the UI behind an ingress/TLS proxy:

```yaml
networkPolicy:
  allowExternal: true
```

## Uninstall

```bash
helm uninstall logs
```

PVCs provisioned for Graylog and the bundled MongoDB and OpenSearch are retained by
Kubernetes on uninstall. Delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=logs
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by
digest. Graylog is licensed under the SSPL (see the notice above); confirm it fits
your use before deploying.

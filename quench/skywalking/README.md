# Quenchworks Apache SkyWalking

Hardened [Apache SkyWalking](https://skywalking.apache.org/) **OAP**
(Observability Analysis Platform) backend — the APM collector that ingests
trace/metric/log data from SkyWalking agents and serves it over a GraphQL query
API. The chart deploys the OAP server only; the Quenchworks image ships the OAP
backend and drops the Rocketbot web UI, so there is no UI workload here.

> **Storage note.** OAP 10.4 accepts Elasticsearch 6/7/8 or any OpenSearch
> distribution, and refuses Elasticsearch 9 outright
> (`UnsupportedOperationException: Unsupported version: ElasticSearch 9.4`). Every
> release of the Quenchworks `elasticsearch` chart ships Elasticsearch 9, so the
> bundled backend here is **OpenSearch** (`opensearch.enabled=true`). An external
> Elasticsearch stays a first-class option as long as it is 8.x or older — see
> [Configuration examples](#configuration-examples).

OAP exposes two ports:

- **gRPC `11800`** — SkyWalking agents push trace/metric/log data.
- **HTTP `12800`** — GraphQL query API + health. Point a SkyWalking UI, Grafana,
  or any GraphQL client at this port to read the data.

OAP is stateless (all durable state lives in the storage backend), so it runs as
a scalable `Deployment`.

## Install

```bash
# self-contained: bundles an in-cluster OpenSearch backend
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set opensearch.enabled=true

# or point at an external OpenSearch / Elasticsearch 8 cluster
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set storage.elasticsearch.clusterNodes="os-host:9200"
```

SkyWalking 10.2+ removed the embedded H2 store, so OAP has no built-in storage
and will not become Ready without a backend. `storage.type` stays
`elasticsearch` either way: OAP 10.4 has no separate `opensearch` selector — its
Elasticsearch client reads the distribution off the cluster root and switches to
the OpenSearch dialect, so one driver serves both. The bundled subchart is
disabled by default to keep the default render dependency-light; enable it, or
supply a cluster via `storage.elasticsearch.clusterNodes`.

## Verify the image

Once the image is published, verify its signature (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/skywalking \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Published images also ship an SPDX SBOM and SLSA build provenance as
attestations. Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/skywalking \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/skywalking` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | OAP replicas (stateless; scales out). |
| `oap.javaOpts` | `-Xms256M -Xmx2048M` | OAP JVM heap options; raise the max for higher ingest. |
| `storage.type` | `elasticsearch` | `SW_STORAGE` selector. Serves OpenSearch too — OAP has no separate `opensearch` selector. |
| `storage.elasticsearch.clusterNodes` | `""` | External OpenSearch / Elasticsearch 8 `host:port` (used when the bundle is disabled). |
| `storage.elasticsearch.protocol` | `http` | `http` or `https`. |
| `storage.elasticsearch.namespace` | `""` | Index namespace prefix. |
| `storage.elasticsearch.user` | `""` | Username for a secured cluster. |
| `storage.elasticsearch.password` | `""` | Rendered into a managed Secret when set (and no `existingSecret`). |
| `storage.elasticsearch.existingSecret` | `""` | Secret already holding the store password. |
| `storage.elasticsearch.existingSecretPasswordKey` | `es-password` | Key within `existingSecret`. |
| `opensearch.enabled` | `false` | Deploy the bundled OpenSearch subchart. |
| `opensearch.mode` | `single` | `single` or `ha` (see the `opensearch` chart). |
| `opensearch.single.heapSize` | `1g` | Bundled node's JVM heap. |
| `opensearch.single.persistence.size` | `16Gi` | Bundled node's PVC size. |
| `resources.requests` | `cpu 500m / mem 1Gi` | |
| `resources.limits` | `cpu 2 / mem 2560Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.grpcPort` | `11800` | Agent data (gRPC) port. |
| `service.restPort` | `12800` | GraphQL query + health port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to the agent + query ports. |
| `networkPolicy.allowExternal` | `false` | Set `true` when agents/UI live in other namespaces. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy). Other storage
selectors (`banyandb`, `mysql`, `postgresql`) are reachable via `storage.type` +
`extraEnvVars`, but only the Elasticsearch/OpenSearch driver is first-class wired
here. Every other `opensearch.*` key is passed straight through to the
[`opensearch` chart](../opensearch/README.md).

## Architecture

OAP runs as a stateless **Deployment** (all durable state lives in the storage
backend, so it scales out). The container runs nonroot (uid 1001) on a read-only
root filesystem; OAP writes only logs and JVM temp files, both backed by writable
`emptyDir` mounts.

Two ports are exposed: **gRPC (11800)** where agents push data and **HTTP
(12800)** for the GraphQL query API and health. The gRPC port binds early, so
liveness watches it to prove the JVM is alive; the query port opens only after
OAP finishes module init against storage, so readiness watches that. OAP's first
boot is slow (JVM start, then connect to storage and create/verify all indices —
often 60-180s on a fresh store), so a startup probe gates liveness and
readiness on the query port with up to 600s of grace (60 × 10s) before normal
probe timing resumes.

Storage lives outside the OAP pod. With `opensearch.enabled=true` the chart
deploys the bundled Quenchworks OpenSearch subchart (`mode: single`) and wires OAP
to `<release>-opensearch:9200` automatically; otherwise
`SW_STORAGE_ES_CLUSTER_NODES` comes from `storage.elasticsearch.clusterNodes`. The
env keys stay ES-flavoured (`SW_STORAGE_ES_*`) because OAP drives OpenSearch with
the same Elasticsearch client. A secured cluster's password is injected as
`SW_ES_PASSWORD` from a Secret and never appears in the pod's process arguments.

## Configuration examples

Point at an external, secured cluster over HTTPS. This is also how you keep using
Elasticsearch: an ES 8.x cluster is fully supported (ES 9 is not), so a site that
already runs ES 8 should disable the bundle and point at it rather than adopt a
second search engine.

```yaml
opensearch:
  enabled: false
storage:
  elasticsearch:
    clusterNodes: "es-1:9200,es-2:9200"
    protocol: https
    user: skywalking
    existingSecret: es-creds
    existingSecretPasswordKey: es-password
```

Size the bundled backend up, or make it a real cluster:

```yaml
opensearch:
  enabled: true
  mode: single
  single:
    heapSize: 4g
    persistence:
      size: 200Gi
```

Raise the JVM heap and scale out for heavier ingest:

```yaml
replicaCount: 3
oap:
  javaOpts: "-Xms1g -Xmx4g"
resources:
  requests: { cpu: "1", memory: 4Gi }
  limits: { cpu: "4", memory: 5Gi }
```

Allow agents and a UI in other namespaces to reach the ports:

```yaml
networkPolicy:
  allowExternal: true
```

## Uninstall

```bash
helm uninstall apm
```

OAP holds no PVCs. If you enabled the bundled OpenSearch, its PVCs are
retained by Kubernetes on uninstall — delete them explicitly if you want the data
gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=apm
```

## Notes

Upgrading from 0.0.4 or older: rename your `elasticsearch:` block to
`opensearch:` (`heapSize` and `persistence` move under `opensearch.single`). The
chart fails the render rather than installing with no storage if the old block is
still present. `storage.elasticsearch.*` did not move.

The chart depends on the `quench-common` library chart and, when enabled, the
`opensearch` subchart, both pulled from `oci://ghcr.io/quenchworks/charts`. It
used to bundle the `elasticsearch` subchart, which could never work: OAP 10.4
rejects Elasticsearch 9 and that is the only major the Quenchworks Elasticsearch
chart ships. Nothing about the external-cluster path changed — `storage.type`
and every `storage.elasticsearch.*` key mean exactly what they did before. The
image runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped, and is pinned by digest.

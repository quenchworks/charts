# Quenchworks Apache SkyWalking

Hardened [Apache SkyWalking](https://skywalking.apache.org/) **OAP**
(Observability Analysis Platform) backend — the APM collector that ingests
trace/metric/log data from SkyWalking agents and serves it over a GraphQL query
API. The chart deploys the OAP server only; the Quenchworks image ships the OAP
backend and drops the Rocketbot web UI, so there is no UI workload here.

> **Status: held.** The OAP image is not currently released as a verified 0-CVE
> build. OAP 10.4 supports Elasticsearch 6/7/8 and OpenSearch only — not the
> Elasticsearch 9 the Quenchworks catalog ships — so the self-contained storage
> path cannot become Ready and the chart is on hold pending an OAP release that
> supports ES9 (or a supported bundled backend). The image aims to be minimal,
> nonroot, cosign-signed (keyless / Sigstore), and pinned by digest like the rest
> of the catalog; treat the hardening and provenance notes below as the intended
> contract for when it ships, not a current guarantee.

OAP exposes two ports:

- **gRPC `11800`** — SkyWalking agents push trace/metric/log data.
- **HTTP `12800`** — GraphQL query API + health. Point a SkyWalking UI, Grafana,
  or any GraphQL client at this port to read the data.

OAP is stateless (all durable state lives in the storage backend), so it runs as
a scalable `Deployment`.

## Install

```bash
# self-contained: bundles an in-cluster Elasticsearch backend
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set elasticsearch.enabled=true

# or point at an external Elasticsearch/OpenSearch cluster
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set storage.elasticsearch.clusterNodes="es-host:9200"
```

SkyWalking 10.2+ removed the embedded H2 store, so OAP has no built-in storage
and will not become Ready without an external backend. This chart wires
Elasticsearch (`SW_STORAGE=elasticsearch`), the only bundled option. The bundled
subchart is disabled by default to keep the default render dependency-light.
See the status note above: the bundled Elasticsearch is ES9-era, which OAP 10.4
does not support.

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
| `storage.type` | `elasticsearch` | `SW_STORAGE` selector. |
| `storage.elasticsearch.clusterNodes` | `""` | External ES `host:port` (used when the bundle is disabled). |
| `storage.elasticsearch.protocol` | `http` | `http` or `https`. |
| `storage.elasticsearch.namespace` | `""` | Index namespace prefix. |
| `storage.elasticsearch.user` | `""` | Username for a secured cluster. |
| `storage.elasticsearch.password` | `""` | Rendered into a managed Secret when set (and no `existingSecret`). |
| `storage.elasticsearch.existingSecret` | `""` | Secret already holding the ES password. |
| `storage.elasticsearch.existingSecretPasswordKey` | `es-password` | Key within `existingSecret`. |
| `elasticsearch.enabled` | `false` | Deploy the bundled Elasticsearch subchart. |
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
`extraEnvVars`, but only Elasticsearch is first-class wired here.

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
often 60-180s on fresh Elasticsearch), so a startup probe gates liveness and
readiness on the query port with up to 600s of grace (60 × 10s) before normal
probe timing resumes.

Storage is external by design. With `elasticsearch.enabled=true` the chart
deploys the bundled Quenchworks Elasticsearch subchart and wires OAP to
`<release>-elasticsearch:9200` automatically; otherwise `SW_STORAGE_ES_CLUSTER_NODES`
comes from `storage.elasticsearch.clusterNodes`. A secured cluster's password is
injected as `SW_ES_PASSWORD` from a Secret and never appears in the pod's process
arguments.

## Configuration examples

Point at an external, secured Elasticsearch/OpenSearch cluster over HTTPS:

```yaml
elasticsearch:
  enabled: false
storage:
  elasticsearch:
    clusterNodes: "es-1:9200,es-2:9200"
    protocol: https
    user: skywalking
    existingSecret: es-creds
    existingSecretPasswordKey: es-password
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

OAP holds no PVCs. If you enabled the bundled Elasticsearch, its PVCs are
retained by Kubernetes on uninstall — delete them explicitly if you want the data
gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=apm
```

## Notes

This chart is currently on hold — see the status note at the top. OAP 10.4
supports Elasticsearch 6/7/8 and OpenSearch only, and the bundled Quenchworks
Elasticsearch is ES9, so the self-contained path does not reach Ready; supply a
supported external ES/OpenSearch cluster if you want to exercise it before the
hold clears. The chart depends on the `quench-common` library chart and, when
enabled, the `elasticsearch` subchart, both pulled from
`oci://ghcr.io/quenchworks/charts`. The image is intended to run nonroot on a
read-only root filesystem with all capabilities dropped and pinned by digest.

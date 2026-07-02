# Quenchworks Apache SkyWalking

Hardened [Apache SkyWalking](https://skywalking.apache.org/) **OAP** (Observability Analysis
Platform) backend — the APM collector that ingests trace/metric/log data from SkyWalking
agents and serves it over a GraphQL query API — on a minimal, nonroot, 0-CVE image pinned by
digest and cosign-signed. OAP runs as uid `1001`.

This chart deploys the **OAP server only**. The Quenchworks image ships the OAP backend (the
CVE surface Trivy scans) and **deliberately drops the Rocketbot web UI**, so there is **no UI
workload** here. OAP exposes:

- **gRPC `11800`** — SkyWalking agents push trace/metric/log data.
- **HTTP `12800`** — GraphQL query API + health. Point a SkyWalking UI, Grafana, or any
  GraphQL client at this port to read the data.

OAP is stateless (all durable state lives in the storage backend), so it runs as a scalable
`Deployment`.

## Storage backend (required)

SkyWalking **10.2+ removed the embedded H2 store**, so OAP has no built-in storage and will
**not become Ready** without an external backend. This chart wires **Elasticsearch**
(`SW_STORAGE=elasticsearch`), the only bundled option:

- **Self-contained** — set `elasticsearch.enabled=true` to run the Quenchworks Elasticsearch
  subchart in-cluster; OAP is wired to `<release>-elasticsearch:9200` automatically.
- **External** — leave `elasticsearch.enabled=false` (the default) and point
  `storage.elasticsearch.clusterNodes` at an existing Elasticsearch/OpenSearch cluster.

The bundled subchart is **disabled by default** to keep the default render dependency-light;
enable it (or supply an external cluster) for any real use.

## Install

```bash
# self-contained: bundles an in-cluster Elasticsearch backend
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set elasticsearch.enabled=true

# or point at an external Elasticsearch/OpenSearch cluster
helm install apm oci://ghcr.io/quenchworks/charts/skywalking \
  --set storage.elasticsearch.clusterNodes="es-host:9200"
```

## Connect

```bash
kubectl port-forward svc/apm-skywalking 12800:12800
# GraphQL query API: http://localhost:12800/graphql
```

SkyWalking agents send data to the gRPC port: `apm-skywalking.<namespace>.svc:11800`.

## Security

By default `networkPolicy.allowExternal` is `false`, restricting the agent and query ports to
the release namespace. Set it `true` when agents or a UI live in other namespaces, or front
OAP with a gateway. For a secured external Elasticsearch, set `storage.elasticsearch.user` and
supply the password via `storage.elasticsearch.password` (rendered into a managed Secret) or
`storage.elasticsearch.existingSecret`; it is injected as `SW_ES_PASSWORD` and never appears in
the pod's process arguments.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/skywalking \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/skywalking` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `replicaCount` | `1` | OAP replicas (stateless; scales out) |
| `oap.javaOpts` | `-Xms256M -Xmx2048M` | OAP JVM heap options |
| `storage.type` | `elasticsearch` | `SW_STORAGE` selector |
| `storage.elasticsearch.clusterNodes` | `""` | External ES `host:port` (when bundle disabled) |
| `elasticsearch.enabled` | `false` | Deploy the bundled Elasticsearch backend |
| `service.grpcPort` | `11800` | Agent data (gRPC) port |
| `service.restPort` | `12800` | GraphQL query + health port |
| `networkPolicy.allowExternal` | `false` | Allow the ports from outside the namespace |

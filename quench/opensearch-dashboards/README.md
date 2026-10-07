# Quenchworks OpenSearch Dashboards

Hardened [OpenSearch Dashboards](https://github.com/opensearch-project/OpenSearch-Dashboards),
the web UI for OpenSearch: Discover, dashboards, visualizations, Dev Tools, alerting,
anomaly detection, observability and the other bundled plugins. The chart runs the
stateless Node UI on port 5601; saved objects live in the cluster's `.kibana` index, so
pods scale out. The image is minimal, runs nonroot (uid 1001) on a read-only root
filesystem with all capabilities dropped, ships 0-CVE, is cosign-signed (keyless /
Sigstore), and the chart pins it by the signed digest, never a tag.

The image ships without the `securityDashboards` and `securityAnalyticsDashboards`
plugins, matching the catalog `opensearch` image, which has no security plugin. There
is no login: anyone who reaches the Service can read and change what the cluster serves.
Keep `networkPolicy.enabled`, or put an authenticating proxy in front.

## Install

Use the same minor as your OpenSearch (`appVersion` is 3.8.0).

```bash
helm install os oci://ghcr.io/quenchworks/charts/opensearch --set mode=single
helm install osd oci://ghcr.io/quenchworks/charts/opensearch-dashboards \
  --set 'opensearch.hosts[0]=http://os-opensearch:9200'
kubectl port-forward svc/osd-opensearch-dashboards 5601:5601   # http://127.0.0.1:5601
```

## Configuration

`opensearch.hosts` and `server.host` are written to `opensearch_dashboards.yml` from a
ConfigMap; `extraConfig` is merged into the same file, for example:

```yaml
extraConfig:
  server.basePath: /dashboards
  server.rewriteBasePath: true
  opensearch.requestTimeout: 60000
```

For a cluster that needs credentials, keep the password out of the values with an
environment reference the config file expands:

```yaml
extraConfig:
  opensearch.username: dashboards
  opensearch.password: ${OSD_PASSWORD}
extraEnvVarsSecret: osd-credentials   # a Secret with an OSD_PASSWORD key
```

| Key | Default | Meaning |
|---|---|---|
| `opensearch.hosts` | `[http://opensearch:9200]` | Cluster URLs |
| `extraConfig` | `{}` | Merged into `opensearch_dashboards.yml` |
| `replicaCount` | `1` | Stateless, scale freely |
| `service.port` | `5601` | Service port |
| `networkPolicy.enabled` | `true` | Ingress from the release namespace, egress DNS + `opensearchPort` |
| `networkPolicy.allowExternal` | `false` | Allow ingress from anywhere |
| `networkPolicy.opensearchPort` | `9200` | Egress port to the cluster |
| `ingress.enabled` | `false` | quench-common Ingress |

Readiness waits for `/api/status`, which fails until the cluster answers; liveness only
checks the port, so an OpenSearch outage marks the pods unready without restarting them.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/opensearch-dashboards \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

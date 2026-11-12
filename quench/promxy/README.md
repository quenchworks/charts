# Quenchworks Promxy

Hardened [Promxy](https://github.com/jacksontj/promxy), a Prometheus aggregating proxy. Grafana
and other clients query one Prometheus-compatible endpoint; Promxy fans the query out to every
configured server group and merges the results. Members of an HA pair go in one group, so a gap
in one replica is filled from the other. The image is built from source, runs as uid 1001 and
is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install pxy oci://ghcr.io/quenchworks/charts/promxy -f my-values.yaml
```

```yaml
config:
  promxy:
    server_groups:
      - static_configs:
          - targets: [prom-a.monitoring:9090, prom-b.monitoring:9090]   # one HA pair
        labels: { region: eu }
      - static_configs:
          - targets: [prom.us.example:9090]
        labels: { region: us }
```

Then point Grafana's Prometheus data source at `http://pxy-promxy:8082`.

## Configuration

`config` is Promxy's own config file as YAML (server groups, remote write, global settings)
and goes to Promxy unchanged.

| Key | Default | What it does |
|---|---|---|
| `config` | one server group at `prometheus-server:9090` | Promxy's config file |
| `replicaCount` | `1` | Promxy is stateless; scale for query load |
| `service.port` | `8082` | Service port |
| `extraArgs` | `[]` | More `promxy` flags (`--query.timeout`, `--web.external-url`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/promxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

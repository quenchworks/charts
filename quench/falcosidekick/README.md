# Quenchworks Falcosidekick

Hardened [Falcosidekick](https://github.com/falcosecurity/falcosidekick): forwards Falco alerts to chat (Slack,
Teams, Mattermost), logs (Loki, Elasticsearch), SIEM, cloud and webhook outputs, and exposes Prometheus metrics. The
image is a static Go binary built from source, runs as uid 1001 on a read-only rootfs and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install sidekick oci://ghcr.io/quenchworks/charts/falcosidekick \
  --set env.SLACK_WEBHOOKURL=https://hooks.slack.com/services/XXX
```

Then point Falco at it: `json_output: true` and `http_output.url: http://sidekick-falcosidekick.<namespace>:2801/`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `env` | `{}` | Output settings as environment variables (`SLACK_WEBHOOKURL`, `LOKI_HOSTPORT`, `WEBHOOK_ADDRESS`, ...) |
| `envSecret` | `""` | A Secret loaded with `envFrom`, for credentials |
| `replicaCount` | `1` | Falcosidekick is stateless |
| `service.port` | `2801` | Where Falco posts events |
| `networkPolicy.enabled` | `true` | Ingress allowed on 2801 only |

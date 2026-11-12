# Quenchworks Gatus

Hardened [Gatus](https://github.com/TwiN/gatus), a health dashboard and uptime monitor. It
checks HTTP, TCP, DNS, ICMP and TLS endpoints on an interval against conditions (status,
body, response time, certificate expiry), keeps the history, serves a status page and sends
alerts to Slack, PagerDuty, email and more. The image is built from source, runs as uid 1001
and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install status oci://ghcr.io/quenchworks/charts/gatus -f my-values.yaml
```

```yaml
config:
  endpoints:
    - name: api
      group: core
      url: https://api.example.com/health
      interval: 30s
      conditions: ["[STATUS] == 200", "[RESPONSE_TIME] < 500", "[CERTIFICATE_EXPIRATION] > 72h"]
  alerting:
    slack:
      webhook-url: https://hooks.slack.com/services/...
```

## Configuration

`config` is Gatus' own config file as YAML and goes to Gatus unchanged, except `storage`,
which the chart sets to SQLite on the volume when persistence is on.

| Key | Default | What it does |
|---|---|---|
| `config` | one example endpoint | Endpoints, alerting, UI, security |
| `persistence.enabled`, `persistence.size` | `true`, `1Gi` | Keep check history in SQLite across restarts |
| `service.port` | `8080` | Status page and API |
| `extraArgs` | `[]` | More `gatus` arguments |

ICMP checks need the `NET_RAW` capability, which the hardened defaults drop; add it with
`containerSecurityContext.capabilities.add: [NET_RAW]` if you use them.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gatus \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

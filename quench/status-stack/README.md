# Quenchworks status-stack

A status page with alerts in one install: [Gatus](https://github.com/TwiN/gatus) 5.38.0 checks your
endpoints and alerts through [ntfy](https://github.com/binwiederhier/ntfy) 2.28.0, and
[Uptime Kuma](https://github.com/louislam/uptime-kuma) 2.5.6 adds monitors you manage in a UI. All
images are QuenchWorks (nonroot, CVE-gated at build, pinned by digest, cosign-signed). From the
first install Gatus checks ntfy and Uptime Kuma and sends alerts to the ntfy topic `status`.

## Install

```bash
helm install status oci://ghcr.io/quenchworks/charts/status-stack -n status --create-namespace
```

Subscribe to alerts with the ntfy app or `curl -s http://status-ntfy:8080/status/json` from the
cluster. Add your endpoints:

```yaml
gatus:
  config:
    endpoints:
      - name: api
        url: https://api.example.com/healthz
        interval: 1m
        conditions: ["[STATUS] == 200", "[RESPONSE_TIME] < 1000"]
        alerts: [{ type: ntfy }]
```

Setting `gatus.config.endpoints` replaces the list, so keep the two stack entries if you want them.

## Values

| Key | Default | Notes |
|---|---|---|
| `gatus.config` | checks of ntfy and Uptime Kuma, ntfy alerting | upstream's Gatus `config.yaml` |
| `gatus.persistence.enabled` | `true` | check history on a volume |
| `ntfy.config.yaml` | `""` | ntfy `server.yml` |
| `uptime-kuma.enabled` | `true` | |

## Notes

- One stack per namespace: the Services are `status-gatus`, `status-ntfy` and
  `status-uptime-kuma` (fixed with `fullnameOverride`), because Gatus's config names them.
- ntfy's defaults let anyone who can reach it publish and subscribe. To lock it down, set
  `auth-default-access: deny-all` in `ntfy.config.yaml`, create a user and token, and give Gatus
  the token (`gatus.config.alerting.ntfy.token`).
- ntfy keeps messages in memory unless `ntfy.persistence.enabled` is set.
- Uptime Kuma has no configuration file: its monitors and notifications are set up in its UI. To
  send them to ntfy, add an ntfy notification with server `http://status-ntfy:8080` and topic
  `status`.

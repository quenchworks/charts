# Quenchworks Alertmanager

Hardened [Prometheus Alertmanager](https://github.com/prometheus/alertmanager),
running on a minimal, nonroot, 0-CVE image pinned by digest. Built from source on
Wolfi. Alertmanager handles alerts sent by Prometheus: it dedups, groups, and
routes them to receivers (email, Slack, PagerDuty, webhook, ...), and manages
silences and inhibition. The web UI + HTTP/v2 API are on port 9093; the HA cluster
gossip mesh is on 9094.

## Install

```bash
helm install alertmanager oci://ghcr.io/quenchworks/charts/alertmanager
```

## Reach the UI / API

The service is ClusterIP (no auth — the NetworkPolicy is the boundary). Port-forward:

```bash
kubectl port-forward svc/alertmanager-alertmanager 9093:9093
# embedded UI:     http://127.0.0.1:9093/
# v2 API status:   http://127.0.0.1:9093/api/v2/status
# lifecycle:       http://127.0.0.1:9093/-/healthy  http://127.0.0.1:9093/-/ready
```

## Point Prometheus at it

In Prometheus' `prometheus.yml`:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager-alertmanager.<namespace>.svc.cluster.local:9093
```

Pairs with the Quenchworks `prometheus` chart (set the target above in its
`config.prometheusYaml`).

## Configure receivers

The full Alertmanager config lives in `alertmanagerConfig` and is rendered
(templated) into a ConfigMap mounted at `/etc/alertmanager/alertmanager.yml`. The
default is a no-op: a single route grouping by `alertname` into a `"null"` receiver
that drops everything. Replace it wholesale with your routing tree + receivers:

```yaml
alertmanagerConfig: |
  global:
    resolve_timeout: 5m
  route:
    receiver: team-slack
    group_by: ["alertname", "cluster"]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - matchers: [severity="critical"]
        receiver: team-pager
  receivers:
    - name: team-slack
      slack_configs:
        - api_url: https://hooks.slack.com/services/XXX
          channel: "#alerts"
    - name: team-pager
      pagerduty_configs:
        - routing_key: <key>
```

`helm upgrade` rolls the pod on the config checksum; or reload live with
`curl -XPOST .../-/reload`.

## High availability

Set `replicaCount` > 1. The pods form a gossip cluster over the `9094` mesh port
(the chart auto-wires `--cluster.listen-address` + a `--cluster.peer` for every
replica at the headless service) so they dedup notifications and share silences.
Point **every** Prometheus at **all** replicas — each Prometheus fans alerts out to
every Alertmanager and the cluster dedups. A single replica disables the mesh.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/alertmanager \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/alertmanager` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | >1 forms an HA gossip cluster on 9094. |
| `alertmanagerConfig` | no-op route + `null` receiver | Full config, templated, mounted from a ConfigMap. |
| `extraArgs` | `[]` | Raw flags appended after the entrypoint's pinned flags. |
| `persistence.enabled` | `true` | 2Gi PVC mounted at `/alertmanager` (nflog + silences state). |
| `service.port` | `9093` | Web UI + HTTP/v2 API + lifecycle endpoints. |
| `service.clusterPort` | `9094` | HA gossip mesh (tcp+udp), used when `replicaCount` > 1. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace (+ gossip among own pods in HA). |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The only writable state is the `/alertmanager` volume (nflog + silences)
and a `/tmp` emptyDir. Alertmanager has **no built-in authentication** — there is
no Secret to manage (unless your receivers reference one). The NetworkPolicy is the
trust boundary; keep it enabled, and front the service with an authenticating proxy
if you must expose it beyond the cluster.

## Notes

Alertmanager keeps local nflog and silences state on disk, so this chart ships a
StatefulSet with a writable `/alertmanager` volume. The default single replica is
self-contained; the HA path (gossip mesh on 9094) is a values flip
(`replicaCount` > 1). Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks EMQX

Hardened [EMQX](https://github.com/emqx/emqx) (the massively scalable distributed
MQTT broker for IoT, IIoT, and connected vehicles) on a minimal, nonroot, 0-CVE
image, pinned by digest and cosign-signed.

> **License:** EMQX 6.x is Business Source License 1.1. A **single node** (the chart
> default) is free for any use; running a **cluster** (`replicaCount > 1`) requires a
> commercial license from EMQ. See the [license FAQ](https://www.emqx.com/en/content/license-faq).

## Install

```sh
helm install emqx oci://ghcr.io/quenchworks/charts/emqx
```

EMQX runs nonroot on a read-only root filesystem as a single-node StatefulSet, with
its node data (mnesia, generated configs, session state) on a persistent
`/opt/emqx/data` volume and logs on an emptyDir at `/opt/emqx/log`.

## Ports

| Port | Name | Purpose |
|------|------|---------|
| `1883` | `mqtt` | MQTT 5.0 (TCP) |
| `8883` | `mqttssl` | MQTT over TLS |
| `8083` | `ws` | MQTT over websockets |
| `8084` | `wss` | MQTT over secure websockets |
| `18083` | `dashboard` | web dashboard + REST API + `/status` |

Liveness/readiness probe `GET /status` on the dashboard port (`18083`); it returns
200 once the node is up (~8s after start).

```sh
kubectl port-forward svc/emqx-emqx 18083:18083
curl http://127.0.0.1:18083/status      # node health
# browse http://127.0.0.1:18083  (admin / <dashboardPassword>)
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/emqx` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | **>1 = cluster, needs a commercial license** |
| `dashboardPassword` | `public` | dashboard admin password (user `admin`) |
| `existingSecret` | `""` | read the password from a Secret instead (wins) |
| `existingSecretPasswordKey` | `dashboard-password` | key in `existingSecret` |
| `persistence.enabled` | `true` | volumeClaimTemplate at `/opt/emqx/data` |
| `persistence.size` | `5Gi` | |
| `persistence.existingClaim` | `""` | reuse a pre-created PVC |
| `service.type` | `ClusterIP` | |
| `service.ports.*` | 1883/8883/8083/8084/18083 | listeners + dashboard |

### Production notes

- **Set a dashboard password** (`dashboardPassword` or `existingSecret`) — the
  upstream default is `admin`/`public`.
- The chart injects a single-node `EMQX_NODE__NAME` bound to the pod IP. For
  clustering (commercial license), use upstream's EMQX Operator or extend this
  chart with EMQX's cluster discovery — the BSL terms apply.
- Tune EMQX via `extraEnvVars` using the `EMQX_*` env override convention
  (e.g. `EMQX_LISTENERS__TCP__DEFAULT__MAX_CONNECTIONS`).

## Verify

```sh
cosign verify ghcr.io/quenchworks/images/emqx \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Uptime Kuma

[Uptime Kuma](https://uptime.kuma.pet) is a self-hosted uptime monitor and status-page
server: HTTP, TCP, ping, DNS, database and push checks, with notifications to email,
chat and many other channels. This chart runs it on the QuenchWorks uptime-kuma image
as a single-replica StatefulSet with its SQLite database on a PVC. The image is
nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install kuma oci://ghcr.io/quenchworks/charts/uptime-kuma
kubectl port-forward svc/kuma-uptime-kuma 3001:3001
```

Open http://127.0.0.1:3001 and create the admin account straight away: until then,
anyone who can reach the UI can claim it.

## Storage

SQLite lives on the PVC at `/app/data` (`persistence.size`, default 2Gi). For an
external MariaDB, set `UPTIME_KUMA_DB_TYPE=mariadb` and the `UPTIME_KUMA_DB_HOSTNAME`,
`UPTIME_KUMA_DB_PORT`, `UPTIME_KUMA_DB_NAME`, `UPTIME_KUMA_DB_USERNAME` and
`UPTIME_KUMA_DB_PASSWORD` variables through `extraEnvVars` or `extraEnvVarsSecret`.

Uptime Kuma runs every check from one process, so keep `replicaCount` at 1.

## Values

| Key | Default | Meaning |
|---|---|---|
| `persistence.enabled` | `true` | PVC for the data dir |
| `persistence.size` | `2Gi` | PVC size |
| `service.port` | `3001` | Service port |
| `ingress.enabled` | `false` | an Ingress for the UI |
| `networkPolicy.enabled` | `true` | restrict ingress to the namespace |
| `networkPolicy.allowExternal` | `false` | allow ingress from any source |

The NetworkPolicy limits ingress only; checks leave the pod freely. ICMP ping monitors
need the cluster's `net.ipv4.ping_group_range` to include uid 1001 (the default on
current containerd and CRI-O).

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind with persistence on, and requires the API
and UI to answer, `/metrics` to demand credentials, and the SQLite database to exist on
the PVC.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

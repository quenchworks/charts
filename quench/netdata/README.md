# netdata

The [Netdata](https://github.com/netdata/netdata) agent as a DaemonSet: one pod per node collects
that node's CPU, memory, disk, network, cgroup (per-pod) and process metrics every second and
serves them over the Netdata REST API and a Prometheus endpoint on port 19999. Runs on the
QuenchWorks netdata image (built from source on Wolfi, nonroot, 0 fixable CVEs, cosign-signed,
pinned by digest).

## Install

```sh
helm install netdata oci://ghcr.io/quenchworks/charts/netdata -n monitoring --create-namespace
kubectl -n monitoring port-forward ds/netdata 19999 &
curl -s localhost:19999/api/v1/info
curl -s 'localhost:19999/api/v1/allmetrics?format=prometheus' | grep netdata_system_cpu
```

## Headless: what this build leaves out

- **No web dashboard.** Upstream does not ship one in its source: the build downloads the
  Netdata Cloud UI from app.netdata.cloud, and that bundle is under the Netdata Cloud UI
  License (NCUL1), which is not an OSI license. No GPL dashboard remains in Netdata 2.x, so this
  image serves only the API (`/api/v1`, `/api/v2`, `/api/v3`) and the Prometheus export
  (`/api/v1/allmetrics?format=prometheus`). Point Grafana or Prometheus at it.
- **No Netdata Cloud.** The agent opens a Cloud connection only after it is claimed with a
  Cloud token; the image ships no claim helper and the chart sets no token. Anonymous
  telemetry is off.
- **Plugins.** Built: the internal collectors (proc, cgroups, diskspace, tc, timex, idlejitter,
  statsd), apps.plugin, cgroup-network, go.d.plugin and ML anomaly detection. Not built:
  python.d, charts.d, eBPF, the OpenTelemetry and NetFlow plugins, systemd journal and units,
  CUPS, FreeIPMI, Xen, NFACCT and the Nagios scripts plugin.

## How it reads the node

The host's `/proc` and `/sys` are mounted read-only at `/host/proc` and `/host/sys`, and the
agent runs with `-s /host` so its collectors read them. The container stays nonroot with a
read-only root filesystem and no capabilities, and mounts no Kubernetes API token. Its state
(`/var/lib/netdata`, `/var/cache/netdata`, `/var/log/netdata`) lives in emptyDirs, so metric
history starts over when the pod restarts. Set `hostPID: true` to let apps.plugin see every
process on the node.

## Values

| Key | Default | Meaning |
|---|---|---|
| `hostPID` | `false` | share the node's PID namespace (per-process metrics for the whole node) |
| `config` | `""` | a full `netdata.conf`; empty keeps the image's (stderr logs, port 19999) |
| `extraArgs` | `[]` | appended to the netdata command, e.g. `["-W", "set", "db", "retention", "7200"]` |
| `extraEnv` | `[]` | extra container environment |
| `service.port` | `19999` | Service port (the container always listens on 19999) |
| `serviceMonitor.enabled` | `false` | ServiceMonitor on the Prometheus export, rendered only when the Prometheus Operator CRD exists |
| `resources` | 100m / 128Mi requests, 512Mi limit | per node |
| `tolerations` | everything | one pod on every node |

## Release gate

The gate installs the chart in kind and passes only when the pod is Ready, `/api/v1/charts`
lists `system.cpu` and a per-cgroup chart for the node's other containers, and the Prometheus
endpoint returns `netdata_system_cpu`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
Netdata is GPL-3.0-or-later.

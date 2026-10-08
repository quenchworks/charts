# node-exporter

The Prometheus [node_exporter](https://github.com/prometheus/node_exporter) as a DaemonSet: one
pod per node exposes that node's CPU, memory, disk, filesystem, network and kernel metrics on
port 9100. Runs on the QuenchWorks node-exporter image (built from source on Wolfi, nonroot,
0 fixable CVEs, cosign-signed, pinned by digest).

## Install

```sh
helm install node-exporter oci://ghcr.io/quenchworks/charts/node-exporter -n monitoring --create-namespace
kubectl -n monitoring port-forward ds/node-exporter 9100 & curl -s localhost:9100/metrics | grep node_uname_info
```

## How it reads the node

As upstream documents for Kubernetes: the pod shares the node's network and PID namespaces
(`hostNetwork`, `hostPID`), and mounts the host's `/proc`, `/sys` and `/` read-only at
`/host/proc`, `/host/sys` and `/host/root`. The container itself stays nonroot with a read-only
root filesystem and no capabilities, and mounts no Kubernetes API token. With `hostNetwork` the
metrics port is opened on each node's address, so keep it firewalled from outside the cluster.

## Values

| Key | Default | Meaning |
|---|---|---|
| `hostNetwork` / `hostPID` | `true` / `true` | node-level network and process metrics |
| `filesystemMountPointsExclude` / `filesystemFsTypesExclude` | upstream defaults | left out of filesystem metrics |
| `extraArgs` | `[]` | enable or disable collectors, e.g. `--collector.systemd` |
| `serviceMonitor.enabled` | `false` | ServiceMonitor, rendered only when the Prometheus Operator CRD exists |
| `tolerations` | everything | one pod on every node |

## Release gate

The gate installs the chart in kind and passes only when `/metrics` on the node's pod reports
`node_uname_info` (the kernel the node runs).

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

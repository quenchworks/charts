# Glances

[Glances](https://nicolargo.github.io/glances/), cross-platform system monitoring: CPU, memory, disks, network,
sensors and processes, in a web UI and a REST API, with exporters (Prometheus, InfluxDB and more). The chart runs one
Glances per node. The image is built from the release wheel by QuenchWorks, CVE-gated, signed with cosign and pinned
by digest.

## Install

```sh
helm install glances oci://ghcr.io/quenchworks/charts/glances
kubectl port-forward ds/glances 61208:61208
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `node.hostPID` | `true` | See the node's processes (otherwise only the pod's). |
| `node.hostSys` | `true` | Mount the node's `/sys` read-only (sensors, disks, interfaces). |
| `extraArgs` | `[]` | Extra `glances` arguments, e.g. `["--export", "prometheus"]`. |
| `networkPolicy.allowExternal` | `true` | `false` limits access to pods labelled `<fullname>-client=true`. |

`hostPID` and the hostPath mount break the restricted and baseline PodSecurity profiles: install it in a namespace that
allows privileged workloads. The web UI and the API have no authentication.

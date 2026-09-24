# Apache Flink

[Apache Flink](https://flink.apache.org) is a stateful stream and batch processing
engine. This chart runs a Flink **session cluster**: one jobmanager (REST API and web UI
on 8081) and a scalable set of taskmanagers, on the QuenchWorks image (the official
binary distribution with the log4j2 jars moved to their fixed release; nonroot, 0 fixable
CVEs, cosign-signed, pinned by digest).

## Install

```sh
helm install flink oci://ghcr.io/quenchworks/charts/flink
kubectl port-forward svc/flink-jobmanager 8081:8081
flink run -m 127.0.0.1:8081 your-job.jar
```

## Configuration

Flink options go in `flinkProperties` and reach both roles as `FLINK_PROPERTIES`:

```yaml
flinkProperties:
  state.backend.type: rocksdb
  execution.checkpointing.interval: 30s
```

| Key | Default | Meaning |
|---|---|---|
| `taskmanager.replicas` | `1` | number of taskmanager pods |
| `taskmanager.numberOfTaskSlots` | `2` | slots per taskmanager |
| `taskmanager.memoryProcessSize` | `1728m` | `taskmanager.memory.process.size` |
| `jobmanager.memoryProcessSize` | `1600m` | `jobmanager.memory.process.size` |
| `flinkProperties` | `{}` | any other Flink option |
| `service.port` | `8081` | REST API / web UI |

Keep each `memoryProcessSize` under that role's container memory limit. There is one
jobmanager and no HA backend configured; for HA, set Flink's Kubernetes or ZooKeeper HA
options in `flinkProperties` and give it durable storage. The optional connectors in
Flink's `opt/` directory are not in the image.

Pods run with a read-only root filesystem, all capabilities dropped, and an emptyDir at
`/tmp` for the working config copy, logs and temporary files. Each taskmanager advertises
its pod IP to the jobmanager.

The release gate installs the chart on kind with two taskmanagers and requires the REST
API to report both registered with 4 slots in total.

The chart depends on the `quench-common` library chart from
`oci://ghcr.io/quenchworks/charts`.

# Quenchworks Apache Storm

Hardened [Apache Storm](https://storm.apache.org) 3.1.0, distributed real-time stream
processing. One image runs every daemon; this chart deploys Nimbus (a StatefulSet with a
PVC for uploaded topologies), supervisors and the UI, with our ZooKeeper chart bundled.

```sh
helm install st oci://ghcr.io/quenchworks/charts/storm
kubectl port-forward svc/st-storm-ui 8080:8080   # http://localhost:8080
```

## Image

`ghcr.io/quenchworks/images/storm`, built from the official binary distribution on Wolfi
`openjdk-25-jre` (Storm 3.1 is Java 25 bytecode), nonroot uid 1001, pinned by digest and
cosign-signed. The optional `external/` connectors and the Kafka offset monitor are not
shipped: topologies bundle their own connectors. Verify the image with
`gh attestation verify oci://ghcr.io/quenchworks/images/storm --owner quenchworks`.

## Values

| Key | Default | Notes |
|---|---|---|
| `nimbus.persistence.enabled` | `true` | Nimbus keeps topology jars in `storm.local.dir` (`/data`) |
| `nimbus.persistence.size` | `8Gi` | |
| `supervisor.replicaCount` | `1` | |
| `supervisor.slotPorts` | `[6700..6703]` | One worker JVM per port; size `supervisor.resources` for them |
| `ui.service.type` / `.port` | `ClusterIP` / `8080` | |
| `extraConfig` | `{}` | storm.yaml keys merged over the chart's |
| `zookeeper.enabled` | `true` | Bundled ZooKeeper; `false` plus `externalZookeeper.servers` for your own |

Each release gets its own ZooKeeper root (`/storm/<release>`), so several releases can
share one external ensemble. Supervisors advertise their pod IP (`storm.local.hostname`).

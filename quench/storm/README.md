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
| `ui.service.httpsPort` | `8443` | UI HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | the UI serves HTTPS only on 8443 (8080 closes) (storm.yaml `ui.https.*`, PKCS12 from an openssl init container) |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |
| `openssl.digest` | (pinned) | init container that builds the PKCS12 keystore |

Each release gets its own ZooKeeper root (`/storm/<release>`), so several releases can
share one external ensemble. Supervisors advertise their pod IP (`storm.local.hostname`).

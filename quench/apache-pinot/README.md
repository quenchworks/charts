# Quenchworks Apache Pinot

Hardened [Apache Pinot](https://github.com/apache/pinot), the real-time distributed OLAP
datastore for low-latency analytics, on a minimal, nonroot, CVE-gated image built from source,
cosign-signed and pinned by digest. One image runs every component; this chart deploys a
controller, a broker and a server (and optionally a minion) on the bundled quench ZooKeeper.

The image is built from the source release, with Pinot's AWS SDK, Parquet and Pulsar
dependencies moved to releases whose bundled jackson copies are fixed, and hadoop-client-runtime's
relocated jackson replaced. Every jackson copy in the image is checked by class at build time,
not only by the scanner, which reads one metadata entry per fat jar.

## Install

```bash
helm install pinot oci://ghcr.io/quenchworks/charts/apache-pinot
```

## Use it

```bash
# the controller's admin API and UI
kubectl port-forward svc/pinot-apache-pinot-controller-api 9000:9000
# queries go to the broker
kubectl port-forward svc/pinot-apache-pinot-broker-api 8099:8099
curl -H 'Content-Type: application/json' -d '{"sql":"select count(*) from myTable"}' \
  http://127.0.0.1:8099/query/sql
```

Create schemas and tables through the controller API or UI, and load data with batch ingestion
jobs (`pinot-admin.sh LaunchDataIngestionJob`) or real-time tables on Kafka or Pulsar.

## Components

| Component | Kind | Port | Storage |
|---|---|---|---|
| controller | StatefulSet | 9000 (API, UI) | PVC: the segment deep store |
| broker | StatefulSet | 8099 (queries) | none |
| server | StatefulSet | 8098 (queries from brokers), 8097 (admin) | PVC: segments and indexes |
| minion | StatefulSet, `minion.enabled` | 9514 | none |

Each instance registers with Helix under its stable pod DNS name, so restarts keep their
identity. Scale servers and brokers with `server.replicas` and `broker.replicas`. More than one
controller needs a shared deep store (S3, GCS, HDFS) instead of the controller's local volume.

## ZooKeeper

The bundled quench ZooKeeper holds the cluster state. To use your own, set
`zookeeper.enabled=false` and `externalZookeeper.address` (`host:port[,host:port][/chroot]`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/apache-pinot \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

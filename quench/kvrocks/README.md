# Apache Kvrocks

[Apache Kvrocks](https://kvrocks.apache.org) is a distributed key-value database built
on RocksDB that speaks the Redis protocol: Redis clients and most Redis commands work,
while the data lives on disk instead of in RAM. This chart runs it on the QuenchWorks
kvrocks image as a StatefulSet with a PVC. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install kv oci://ghcr.io/quenchworks/charts/kvrocks
PASSWORD=$(kubectl get secret kv-kvrocks -o jsonpath='{.data.password}' | base64 -d)
```

Connect any Redis client to `kv-kvrocks.<namespace>.svc:6666` with that password.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.existingSecret` | `""` | a Secret with a `password` key; empty generates one, kept across upgrades |
| `extraArgs` | `[]` | extra kvrocks flags (`--workers`, `--rocksdb.*`, ...) |
| `persistence.enabled` | `true` | a PVC for `/var/lib/kvrocks` |
| `persistence.size` | `8Gi` | PVC size |
| `service.port` | `6666` | Redis-protocol port |

The chart runs one instance. Pods run with a read-only root filesystem and all
capabilities dropped; the image logs to stdout.

The release gate installs the chart on kind with persistence on, writes a key with
`valkey-cli`, requires an unauthenticated client to be refused, deletes the pod, and
requires the key to be back after the restart.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

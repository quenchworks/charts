# Quenchworks Distribution (OCI registry)

Hardened [Distribution](https://github.com/distribution/distribution) registry, the
CNCF reference OCI/Docker registry server, on a minimal, nonroot, 0-CVE image built
from source and pinned by digest.

## Install

```sh
helm install registry oci://ghcr.io/quenchworks/charts/distribution
```

Runs as a single-replica StatefulSet with a persistent blob store at
`/var/lib/registry` and the registry API on port 5000. Check it from a client pod:

```sh
kubectl run reg-check --rm -it --restart=Never --image=ghcr.io/quenchworks/images/busybox -- \
  wget -qS -O- http://registry-distribution:5000/v2/
```

## Configuration

The registry is configured by `config.configYml`, written to a ConfigMap and
mounted over the image default at `/etc/distribution/config.yml`. The default uses
filesystem storage on the PVC. Edit it (and `helm upgrade`) to switch to S3/GCS,
enable authentication, or add TLS, or point `config.existingConfigMap` at a
ConfigMap (key `config.yml`) you manage yourself.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/distribution` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | filesystem storage is single-writer; scale-out needs shared storage |
| `config.configYml` | filesystem on the PVC, API on :5000 | the registry config |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `config.yml`, wins) |
| `persistence.enabled` | `true` | blob store volume at `/var/lib/registry` |
| `persistence.size` | `10Gi` | |
| `service.type` | `ClusterIP` | |
| `service.port` | `5000` | registry HTTP API |

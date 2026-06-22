# Quenchworks CoreDNS

Hardened [CoreDNS](https://github.com/coredns/coredns) DNS server on a minimal,
nonroot, 0-CVE image, built from source and pinned by digest.

## Install

```sh
helm install dns oci://ghcr.io/quenchworks/charts/coredns
```

The server runs nonroot, so it binds DNS on the unprivileged port 1053; the
Service maps 53 (UDP and TCP) to it. Resolve a name from a client pod:

```sh
kubectl run dnsutils --rm -it --restart=Never --image=ghcr.io/quenchworks/images/busybox -- \
  nslookup quench-works.com dns-coredns
```

## Configuration

CoreDNS is configured by a Corefile. The chart ships a sane default in
`config.corefile` (health, ready, whoami, forward to the node resolvers, cache).
It is written to a ConfigMap and mounted over the image default at
`/etc/coredns/Corefile`. Edit `config.corefile` and `helm upgrade`, or point
`config.existingConfigMap` at an externally-managed ConfigMap whose `Corefile`
key holds the config.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/coredns` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `config.corefile` | health/ready/whoami/forward/cache | the Corefile |
| `config.existingConfigMap` | `""` | external Corefile ConfigMap (wins) |
| `service.type` | `ClusterIP` | |
| `service.port` | `53` | Service maps 53 -> container 1053 |

To bind the privileged port 53 inside the container instead, grant
`NET_BIND_SERVICE` via `containerSecurityContext.capabilities.add` and set the
Corefile to listen on `.:53`.

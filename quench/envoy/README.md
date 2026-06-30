# Quenchworks Envoy

Hardened [Envoy](https://github.com/envoyproxy/envoy), the CNCF high-performance
L7 edge/service proxy, on a minimal, nonroot, 0-CVE image, pinned by digest.

## Install

```sh
helm install proxy oci://ghcr.io/quenchworks/charts/envoy
```

The container runs `envoy -c /etc/envoy/envoy.yaml --service-cluster <release>`
nonroot. Out of the box it serves a default bootstrap: an admin endpoint on
`0.0.0.0:9901` and one example listener on `:10000` that returns a 200
`direct_response`. The Service exposes both. Check readiness over a port-forward:

```sh
kubectl port-forward svc/proxy-envoy 9901:9901 10000:10000
curl http://127.0.0.1:9901/ready   # 200 LIVE
curl http://127.0.0.1:10000/       # 200
```

## Configuration

Envoy is a standalone proxy driven entirely by its bootstrap config. Replace the
default with your own: set `config` to the full bootstrap YAML (a string) and it
is written to a ConfigMap, mounted at `/etc/envoy/envoy.yaml`, and passed via
`-c`. Point `existingConfigMap` at an externally-managed ConfigMap (key
`envoy.yaml`) to use that instead (it wins over `config`).

The root filesystem is read-only; Envoy's admin socket and logs live on an
emptyDir mounted at `/tmp`.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/envoy` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `config` | `""` | inline bootstrap YAML (mounted, passed via `-c`); empty = chart default |
| `existingConfigMap` | `""` | external bootstrap ConfigMap (key `envoy.yaml`, wins) |
| `serviceCluster` | release name | `--service-cluster` value |
| `extraArgs` | `[]` | appended to the `envoy` command |
| `service.type` | `ClusterIP` | |
| `service.port` | `10000` | proxy listener |
| `service.adminPort` | `9901` | admin/health endpoint |
| `autoscaling.enabled` | `false` | HPA on CPU |

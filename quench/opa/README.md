# Quenchworks OPA

Hardened [Open Policy Agent](https://github.com/open-policy-agent/opa) on a
minimal, nonroot, 0-CVE image, built from source and pinned by digest.

## Install

```sh
helm install policy oci://ghcr.io/quenchworks/charts/opa
```

The server runs nonroot and serves the policy API on container port 8181; the
Service exposes it on the same port. Check health over a port-forward:

```sh
kubectl port-forward svc/policy-opa 8181:8181
curl http://127.0.0.1:8181/health
```

## Configuration

OPA runs as `opa run --server --addr=0.0.0.0:8181`. By default it uses the
in-memory store with an empty policy set; load policies via the REST API or
configure signed bundles. Set `config.yaml` to an OPA configuration (bundles,
decision logs, status); it is written to a ConfigMap, mounted at
`/config/config.yaml`, and passed via `-c`. Point `config.existingConfigMap` at
an externally-managed ConfigMap (key `config.yaml`) to use that instead.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/opa` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `config.yaml` | `""` | inline OPA config (mounted, passed via `-c`) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `config.yaml`, wins) |
| `extraArgs` | `[]` | appended to the `opa run` command |
| `service.type` | `ClusterIP` | |
| `service.port` | `8181` | policy API |

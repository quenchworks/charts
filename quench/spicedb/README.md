# Quenchworks SpiceDB

Hardened [SpiceDB](https://github.com/authzed/spicedb) (Authzed's Google
Zanzibar-inspired authorization database) on a minimal, nonroot, 0-CVE image,
pinned by digest and cosign-signed.

## Install

```sh
helm install authz oci://ghcr.io/quenchworks/charts/spicedb
```

The server runs nonroot and serves the gRPC authorization API on container port
50051; the Service exposes it in-cluster. The gRPC preshared key is generated on
first install and stored in a Secret. Read it and talk to the API over a
port-forward:

```sh
kubectl get secret authz-spicedb -o jsonpath='{.data.preshared-key}' | base64 -d
kubectl port-forward svc/authz-spicedb 50051:50051
grpcurl -plaintext -H "authorization: bearer <preshared-key>" \
  localhost:50051 grpc.health.v1.Health/Check
```

## Configuration

SpiceDB runs as `spicedb serve --datastore-engine <engine>`. By default it uses
the in-memory datastore, which is not persistent and cannot be safely replicated
(`replicaCount` stays at 1). For production, set `datastore.engine` to a
persistent backend (`postgres`, `cockroachdb`, `mysql`, `spanner`) and
`datastore.uri` to its connection string, then scale out.

The gRPC API **requires** a preshared key. This chart wires it into the pod via
the `SPICEDB_GRPC_PRESHARED_KEY` env var, sourced from a Secret. Leave
`grpcPresharedKey.value` empty to auto-generate one (preserved across upgrades),
set it to rotate, or point `grpcPresharedKey.existingSecret` at a Secret you
manage. Treat this key as the root credential to the authorization API.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/spicedb` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment (memory datastore) |
| `datastore.engine` | `memory` | `--datastore-engine`; use a persistent engine in prod |
| `datastore.uri` | `""` | `--datastore-conn-uri` for a persistent engine |
| `grpcPresharedKey.value` | `""` | generated (32 chars) if empty; stored in the Secret |
| `grpcPresharedKey.existingSecret` | `""` | external Secret holding the key (wins) |
| `grpcPresharedKey.existingSecretKey` | `preshared-key` | key within `existingSecret` |
| `httpGateway.enabled` | `false` | expose the HTTP/JSON gateway on 8443 |
| `extraArgs` | `[]` | appended to `spicedb serve` |
| `service.type` | `ClusterIP` | |
| `service.grpcPort` | `50051` | gRPC authorization API |
| `service.metricsPort` | `9090` | Prometheus `/metrics` |
| `service.gatewayPort` | `8443` | HTTP/JSON gateway (when enabled) |
| `autoscaling.enabled` | `false` | CPU HPA (needs a shared datastore) |
| `networkPolicy.enabled` | `true` | ingress to grpc/metrics ports |
| `networkPolicy.allowExternal` | `true` | allow cross-namespace ingress |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1` |

## Security

- Nonroot (UID 1001), read-only root filesystem, all capabilities dropped,
  `allowPrivilegeEscalation: false`, seccomp `RuntimeDefault`.
- Image pinned by digest and cosign-signed (keyless / Sigstore):

  ```sh
  cosign verify ghcr.io/quenchworks/images/spicedb \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

- Rotate the gRPC preshared key for production. TLS is not enabled by default;
  terminate TLS at an ingress/gateway or pass the `spicedb serve` TLS flags via
  `extraArgs`.

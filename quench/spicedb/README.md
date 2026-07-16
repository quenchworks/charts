# Quenchworks SpiceDB

Hardened [SpiceDB](https://github.com/authzed/spicedb) — Authzed's open-source,
Google Zanzibar-inspired database for fine-grained authorization (ReBAC /
relationship-based permissions) over a gRPC API — on a minimal, nonroot, 0-CVE
image, cosign-signed (keyless / Sigstore) and pinned by digest. It runs
`spicedb serve` as a stateless Deployment and serves the gRPC API on port 50051.

## Install

```bash
helm install authz oci://ghcr.io/quenchworks/charts/spicedb
```

The gRPC preshared key is generated on first install and stored in a Secret
(preserved across upgrades). Read it and talk to the API over a port-forward:

```bash
kubectl get secret authz-spicedb -o jsonpath='{.data.preshared-key}' | base64 -d
kubectl port-forward svc/authz-spicedb 50051:50051
grpcurl -plaintext -H "authorization: bearer <preshared-key>" \
  localhost:50051 grpc.health.v1.Health/Check
```

Point at a persistent datastore for production:

```bash
helm install authz oci://ghcr.io/quenchworks/charts/spicedb \
  --set datastore.engine=postgres \
  --set datastore.uri="postgres://user:pass@pg:5432/spicedb?sslmode=require"
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/spicedb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/spicedb \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/spicedb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment; keep at 1 with the memory datastore. |
| `datastore.engine` | `memory` | `--datastore-engine`; use a persistent engine (`postgres`, `cockroachdb`, `mysql`, `spanner`) in prod. |
| `datastore.uri` | `""` | `--datastore-conn-uri` for a persistent engine. |
| `grpcPresharedKey.value` | `""` | Generated (32 chars) if empty; stored in the Secret. |
| `grpcPresharedKey.existingSecret` | `""` | External Secret holding the key (wins over `value`). |
| `grpcPresharedKey.existingSecretKey` | `preshared-key` | Key within `existingSecret`. |
| `httpGateway.enabled` | `false` | Expose the HTTP/JSON gateway on 8443. |
| `extraArgs` | `[]` | Appended to the `spicedb serve` command. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.grpcPort` | `50051` | gRPC authorization API (native protocol). |
| `service.metricsPort` | `9090` | Prometheus `/metrics`. |
| `service.gatewayPort` | `8443` | HTTP/JSON gateway (only routed when `httpGateway.enabled`). |
| `autoscaling.enabled` | `false` | HPA on CPU (needs a shared datastore). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress to the gRPC + metrics ports. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs `spicedb serve`. The gRPC API **requires** a
preshared key (`--grpc-preshared-key`) — the server refuses to serve without one
— which the chart injects as `SPICEDB_GRPC_PRESHARED_KEY` from a Secret; treat it
as the root credential to the authorization API. Liveness `httpGet /metrics` on
the metrics port and readiness does a TCP connect to the gRPC port, so a pod
takes traffic only once it is accepting work.

With the default in-memory datastore, state is per-pod and non-persistent, so
`replicaCount` stays at 1 and autoscaling is off. Switching `datastore.engine` to
a persistent backend (`postgres`, `cockroachdb`, `mysql`, `spanner`) with a
shared `datastore.uri` makes it safe to scale out or enable the CPU HPA. The
container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped, `allowPrivilegeEscalation: false`, and seccomp
`RuntimeDefault`.

The **gRPC API (50051)** is the native protocol; **metrics (9090)** serves
Prometheus `/metrics`; the **HTTP/JSON gateway (8443)** is only routed when
`httpGateway.enabled` is set.

## Configuration examples

Run against PostgreSQL with a rotated preshared key from your own Secret, and
scale out:

```yaml
replicaCount: 3
datastore:
  engine: postgres
  uri: postgres://user:pass@pg:5432/spicedb?sslmode=require
grpcPresharedKey:
  existingSecret: spicedb-key
  existingSecretKey: preshared-key
autoscaling:
  enabled: true
  maxReplicas: 8
```

Enable the HTTP/JSON gateway and pass extra `spicedb serve` flags:

```yaml
httpGateway:
  enabled: true
extraArgs:
  - "--log-level=warn"
```

## Uninstall

```bash
helm uninstall authz
```

The managed preshared-key Secret is retained by Kubernetes on uninstall — delete
it explicitly if you want it gone (and it holds no state when a persistent
datastore is used, which lives in your external database):

```bash
kubectl delete secret authz-spicedb
```

## Notes

Default in-memory datastore for a single node; use a persistent, shared engine
before scaling out. TLS is not enabled by default — terminate TLS at an
ingress/gateway or pass the `spicedb serve` TLS flags via `extraArgs`. The chart
depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned
by digest.

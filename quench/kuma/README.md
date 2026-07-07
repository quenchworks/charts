# Quenchworks Kuma

Hardened [Kuma](https://github.com/kumahq/kuma) service mesh control plane
(`kuma-cp`) on a minimal, nonroot, 0-CVE image, built from source and pinned by
digest.

## Install

```sh
helm install mesh oci://ghcr.io/quenchworks/charts/kuma
```

This chart runs a single `kuma-cp` in standalone/universal mode with the
**in-memory store** (`KUMA_STORE_TYPE=memory`), so it needs no external database
and no Kubernetes CRDs. Reach the API and GUI over a port-forward:

```sh
kubectl port-forward svc/mesh-kuma 5681:5681
curl http://127.0.0.1:5681/       # {"product":"Kuma","version":...}
# open http://127.0.0.1:5681/gui
```

## Store & mode (ephemeral by design)

The in-memory store keeps all mesh state in process: meshes, policies and tokens
are **lost on restart**, and the control plane cannot be scaled beyond one replica
(each replica has its own private store). This is ideal for demos, evaluation and
small universal-mode setups.

For durable state and HA, run `kuma-cp` with the **postgres** store
(`store: postgres` plus the relevant `KUMA_STORE_POSTGRES_*` env vars via
`extraEnvVars`) or use the upstream Kubernetes (CRD) deployment.

The control plane runs with a read-only root filesystem; its work directory (CA
and signing keys) is redirected to a writable `emptyDir` at `/tmp` via
`KUMA_GENERAL_WORK_DIR`.

## Ports

| Port | Name | Purpose |
|------|------|---------|
| 5681 | `http` | REST API + GUI (`/gui`) |
| 5682 | `https` | REST API over TLS |
| 5678 | `dp-server` | dataplane / xDS gRPC (kuma-dp sidecars connect here) |
| 5676 | `mads` | monitoring-assignment gRPC (Prometheus service discovery) |
| 5680 | `diagnostics` | health endpoints `/healthy` (liveness) and `/ready` (readiness); not exposed on the Service |

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/kuma` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | in-memory store is single-node; keep at 1 |
| `store` | `memory` | wired to `KUMA_STORE_TYPE` |
| `mode` | `standalone` | wired to `KUMA_MODE` (universal single CP) |
| `workDir` | `/tmp` | wired to `KUMA_GENERAL_WORK_DIR`; writable emptyDir |
| `extraArgs` | `[]` | appended to `kuma-cp run` |
| `extraEnvVars` | `[]` | extra `KUMA_*` env (e.g. postgres store settings) |
| `service.type` | `ClusterIP` | |
| `service.ports.*` | `5681/5682/5678/5676` | http / https / dp-server / mads |

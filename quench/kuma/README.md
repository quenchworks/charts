# Quenchworks Kuma

Hardened [Kuma](https://github.com/kumahq/kuma) service mesh control plane
(`kuma-cp`) on a minimal, nonroot, 0-CVE image, built from source, cosign-signed
and pinned by digest. This chart runs a single `kuma-cp` in standalone/universal
mode with the in-memory store (`KUMA_STORE_TYPE=memory`), so it needs no external
database and no Kubernetes CRDs. The container runs nonroot on a read-only root
filesystem with all capabilities dropped.

## Install

```sh
helm install mesh oci://ghcr.io/quenchworks/charts/kuma
```

Reach the API and GUI over a port-forward:

```sh
kubectl port-forward svc/mesh-kuma 5681:5681
curl http://127.0.0.1:5681/       # {"product":"Kuma","version":...}
# open http://127.0.0.1:5681/gui
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/kuma \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```sh
gh attestation verify oci://ghcr.io/quenchworks/images/kuma --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/kuma` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Fixed at 1: the in-memory store is single-node. |
| `store` | `memory` | Wired to `KUMA_STORE_TYPE` (`memory` or `postgres`). |
| `mode` | `standalone` | Wired to `KUMA_MODE` (`standalone`, `zone`, or `global`). |
| `workDir` | `/tmp` | Wired to `KUMA_GENERAL_WORK_DIR`; a writable emptyDir holding the CA and signing keys. |
| `extraArgs` | `[]` | Appended to `kuma-cp run`. |
| `extraEnvVars` | `[]` | Extra `KUMA_*` env (for example postgres store settings). |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.ports.http` | `5681` | REST API + GUI. |
| `service.ports.https` | `5682` | REST API over TLS. |
| `service.ports.dpServer` | `5678` | Dataplane / xDS gRPC. |
| `service.ports.mads` | `5676` | Monitoring-assignment gRPC (Prometheus SD). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A single `kuma-cp` runs as a Deployment behind a Service. Five ports are used:
`5681` (REST API + `/gui`), `5682` (REST API over TLS), `5678` (dataplane / xDS
gRPC that kuma-dp sidecars connect to) and `5676` (monitoring-assignment gRPC for
Prometheus service discovery) are published on the Service; `5680` (diagnostics)
serves the health endpoints `/healthy` (liveness) and `/ready` (readiness) and is
not exposed.

The in-memory store keeps all mesh state in the process: meshes, policies and
tokens are lost on restart, and the control plane cannot be scaled beyond one
replica because each replica has its own private store. This fits demos,
evaluation and small universal-mode setups. The control plane runs with a
read-only root filesystem, so its work directory (CA and signing keys) is
redirected to a writable `emptyDir` at `/tmp` via `KUMA_GENERAL_WORK_DIR`.

## Configuration examples

Durable state with an external PostgreSQL store:

```yaml
store: postgres
extraEnvVars:
  - name: KUMA_STORE_POSTGRES_HOST
    value: pg.example.com
  - name: KUMA_STORE_POSTGRES_PORT
    value: "5432"
  - name: KUMA_STORE_POSTGRES_DB_NAME
    value: kuma
  - name: KUMA_STORE_POSTGRES_USER
    value: kuma
  - name: KUMA_STORE_POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: kuma-postgres
        key: password
```

## Uninstall

```sh
helm uninstall mesh
```

The in-memory store holds no PVCs, so nothing persists.

## Notes

The in-memory topology is single-node and ephemeral. For durable state and HA,
run `kuma-cp` with the postgres store (shown above) or use the upstream
Kubernetes (CRD) deployment. The chart depends on the `quench-common` library
chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`. The
container runs as nonroot on a read-only root filesystem with all capabilities
dropped, and the image is pinned by digest.

# Quenchworks OPA

Hardened [Open Policy Agent](https://github.com/open-policy-agent/opa), the CNCF
general-purpose policy engine for authorization, admission control, and config
validation over Rego, on a minimal, nonroot, 0-CVE image built from source,
cosign-signed and pinned by digest. Runs in server mode (`opa run --server`) as a
stateless Deployment and serves the policy API on port 8181.

## Install

```bash
helm install policy oci://ghcr.io/quenchworks/charts/opa
```

The server runs nonroot on container port 8181; the Service exposes the same
port. Check health over a port-forward:

```bash
kubectl port-forward svc/policy-opa 8181:8181
curl http://127.0.0.1:8181/health
```

Load a config (bundles, decision logs) inline:

```bash
helm install policy oci://ghcr.io/quenchworks/charts/opa \
  --set-file config.yaml=./opa-config.yaml
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/opa \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/opa --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/opa` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `config.yaml` | `""` | Inline OPA config (bundles, decision logs, status). Written to a ConfigMap, mounted at `/config/config.yaml`, passed via `-c`. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `config.yaml`) instead; wins over `config.yaml`. |
| `extraArgs` | `[]` | Extra flags appended to the `opa run` command. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8181` | Policy API (query + management). |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs the server via
`opa run --server --addr=0.0.0.0:8181` on container port `8181`; the Service maps
the same port. With the default in-memory store and no config, OPA starts with an
empty policy set — load policies over the REST API or point it at signed bundles.
When `config.yaml` is set (and no `config.existingConfigMap`), it renders to a
ConfigMap mounted read-only at `/config` and appended to the command as
`-c /config/config.yaml`; `extraArgs` are appended after that. Liveness and
readiness both `httpGet /health` (200 once the server is up and, when bundles are
configured, they have loaded). Because the default store is in-memory, the
workload scales horizontally with no coordination — enable `autoscaling` (HPA on
CPU) or raise `replicaCount`. The container runs nonroot on a read-only root
filesystem with all capabilities dropped; the only mount is the read-only config
ConfigMap (when present).

## Configuration examples

Pull a signed policy bundle from a registry and stream decision logs to the
console:

```yaml
config:
  yaml: |
    services:
      registry:
        url: https://registry.example.com
    bundles:
      authz:
        service: registry
        resource: bundles/authz/bundle.tar.gz
        polling:
          min_delay_seconds: 30
          max_delay_seconds: 120
    decision_logs:
      console: true
    status:
      console: true
```

Add server flags, e.g. quieter logs and diagnostic addr:

```yaml
extraArgs:
  - "--log-level=warn"
  - "--diagnostic-addr=0.0.0.0:8282"
```

## Uninstall

```bash
helm uninstall policy
```

Nothing persists — the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. OPA serves the policy API without authentication by default —
use OPA's own authentication/authorization (`--authentication`,
`--authorization` via `extraArgs`) and keep the NetworkPolicy as the trust
boundary before exposing it beyond the cluster.

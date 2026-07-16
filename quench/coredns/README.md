# Quenchworks CoreDNS

Hardened [CoreDNS](https://github.com/coredns/coredns), the plugin-chained DNS
server and default cluster DNS for Kubernetes, on a minimal, nonroot, 0-CVE image
built from source and pinned by digest. It runs as a stateless Deployment and
serves DNS on port 53 (UDP and TCP), on a read-only root filesystem with all
capabilities dropped. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/coredns
```

The server runs nonroot, so it binds DNS on the unprivileged port 1053; the
Service maps 53 (UDP and TCP) to it. Resolve a name from a client pod:

```bash
kubectl run dnsutils --rm -it --restart=Never --image=ghcr.io/quenchworks/images/busybox -- \
  nslookup quench-works.com dns-coredns
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/coredns \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/coredns --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/coredns` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `config.corefile` | health/ready/whoami/forward/cache | The Corefile, mounted over `/etc/coredns/Corefile`. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `Corefile`) instead; wins over `corefile`. |
| `resources.requests` | `cpu 50m / mem 32Mi` | |
| `resources.limits` | `cpu 250m / mem 128Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `53` | DNS Service port (maps 53 -> container 1053). |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. DNS is usually queried cluster-wide, so this defaults open. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs CoreDNS behind a DNS Service. The container binds the
unprivileged port `1053` so it runs nonroot with no added capabilities, and the
Service maps `53` (UDP and TCP) to it. CoreDNS is configured by a Corefile: the
chart renders `config.corefile` to a ConfigMap and mounts it over the image's
`-conf` path at `/etc/coredns/Corefile`. The default Corefile serves `health`
(`:8080`) and `ready` (`:8181`), which back the liveness and readiness probes,
answers with `whoami`, and forwards everything else to the node resolvers with a
30s cache. The root filesystem is read-only; there is no persistence, and the
workload scales horizontally with `autoscaling` or `replicaCount`.

## Configuration examples

Point the forwarder at explicit upstreams and enable autoscaling:

```yaml
config:
  corefile: |
    .:1053 {
        health :8080
        ready :8181
        forward . 1.1.1.1 8.8.8.8
        cache 30
        log
        errors
    }
autoscaling:
  enabled: true
  maxReplicas: 8
```

Bring your own Corefile ConfigMap (managed outside the chart, key `Corefile`):

```yaml
config:
  existingConfigMap: my-corefile
```

To bind the privileged port 53 inside the container instead, grant
`NET_BIND_SERVICE` via `containerSecurityContext.capabilities.add` and set the
Corefile to listen on `.:53`.

## Uninstall

```bash
helm uninstall dns
```

Nothing persists: the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

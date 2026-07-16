# Quenchworks NATS

Hardened [NATS](https://github.com/nats-io/nats-server) — a lightweight,
high-performance messaging system for cloud-native pub/sub and request-reply — on
a minimal, nonroot, 0-CVE image pinned by digest. Runs a single combined server
with JetStream persistence on by default; the chart owns the server command so
flags are deterministic. The image is cosign-signed (keyless / Sigstore) and the
chart pins it by the signed digest, never a tag.

## Install

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats
```

Core NATS only (no JetStream, no persistence):

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats \
  --set nats.jetstream.enabled=false --set persistence.enabled=false
```

Pass any other server flag without changing the chart:

```bash
helm install my-nats oci://ghcr.io/quenchworks/charts/nats \
  --set 'nats.extraArgs[0]=--max_payload' \
  --set 'nats.extraArgs[1]=8MB'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nats \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/nats --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/nats` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Single combined server; clustering is a follow-up. |
| `nats.jetstream.enabled` | `true` | Enable JetStream; the store lives on the data volume. |
| `nats.extraArgs` | `[]` | Any extra `nats-server` flags (auth, TLS, limits). |
| `persistence.enabled` | `true` | 8Gi PVC at `/data` for the JetStream store. |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 100m / mem 128Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.clientPort` | `4222` | Client connections. |
| `service.monitorPort` | `8222` | HTTP monitoring (`/healthz`, `/varz`); probes use it. |
| `service.clusterPort` | `6222` | Route connections between servers (headless). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts client ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow client ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`, scheduling
(`affinity`/`nodeSelector`/`tolerations`/`topologySpreadConstraints`),
`initContainers`, `sidecars`, `extraVolumes`/`extraVolumeMounts`, `lifecycleHooks`,
configurable probes, and overridable security contexts.

## Architecture

NATS runs as a **StatefulSet** so the server keeps a stable network identity and
its own persistent volume, backed by a headless Service for stable per-server DNS
(the basis for future route discovery). JetStream state lives on a PVC mounted at
`/data` via a `volumeClaimTemplate`; with `persistence.enabled=false` the store is
an `emptyDir` and does not survive a restart, and with `nats.jetstream.enabled=false`
the server runs pure core NATS (PUB/SUB, no persistence).

Three ports are exposed: **client (4222)** for connections, **monitor (8222)** for
the HTTP monitoring endpoints, and **cluster (6222)** for inter-server routes over
the headless Service. Liveness and readiness both `httpGet /healthz` on the monitor
port.

The container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped; only `/data` and `/tmp` are writable.

## Configuration examples

Core NATS with a larger payload limit and no persistence:

```yaml
persistence:
  enabled: false
nats:
  jetstream:
    enabled: false
  extraArgs:
    - "--max_payload"
    - "8MB"
```

JetStream on a named storage class, with a Prometheus exporter sidecar (NATS has
no native Prometheus endpoint):

```yaml
persistence:
  enabled: true
  size: 20Gi
sidecars:
  - name: exporter
    image: natsio/prometheus-nats-exporter:latest
    args: ["-varz", "http://localhost:8222"]
    ports:
      - name: metrics
        containerPort: 7777
```

## Uninstall

```bash
helm uninstall my-nats
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the JetStream store gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-nats
```

## Notes

Single-node, no authentication, reachable only inside the cluster (the
NetworkPolicy restricts client ingress to the release namespace). Multi-node
clustering, auth/TLS, and a first-class metrics path (NATS exposes monitoring as
JSON at `/varz`; add the prometheus-nats-exporter via the `sidecars` knob) are
tracked follow-ups. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

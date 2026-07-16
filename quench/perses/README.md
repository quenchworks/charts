# Quenchworks Perses

Hardened [Perses](https://github.com/perses/perses), the CNCF open dashboard and
observability visualization tool, running as a stateless Deployment that serves
the UI and API on port 8080. Built from source on a minimal, nonroot, 0-CVE
image that runs on a read-only root filesystem with all capabilities dropped.
The image is cosign-signed (keyless / Sigstore) and the chart pins it by the
signed digest, never a tag.

## Install

```bash
helm install dash oci://ghcr.io/quenchworks/charts/perses
```

Keep dashboards across restarts by enabling a PersistentVolumeClaim for the file
datastore:

```bash
helm install dash oci://ghcr.io/quenchworks/charts/perses \
  --set persistence.enabled=true \
  --set persistence.size=8Gi \
  --set persistence.storageClass=fast-ssd
```

The server runs nonroot on container port 8080; the Service maps the same port.
Open the UI and check health over a port-forward:

```bash
kubectl port-forward svc/dash-perses 8080:8080
# UI:     http://127.0.0.1:8080/
# Health: http://127.0.0.1:8080/api/v1/health
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/perses \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/perses \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/perses` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment. File datastore is per-pod; scale out only with a shared backend. |
| `extraArgs` | `[]` | Extra flags appended to the `perses` command. |
| `persistence.enabled` | `false` | PVC-backed datastore. When `false`, uses an `emptyDir` (dashboards lost on restart). |
| `persistence.path` | `/perses` | File datastore folder; must match the folder in the perses config. |
| `persistence.size` | `8Gi` | Requested volume size when enabled. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC. |
| `persistence.existingClaim` | `""` | Bind an externally-managed PVC instead of provisioning one. |
| `resources.requests` | `cpu 100m / mem 128Mi` | CPU / memory requests. |
| `resources.limits` | `cpu 1 / mem 512Mi` | CPU / memory limits. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | UI and API. |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). Only safe with a shared datastore backend. |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Perses runs as a **Deployment** behind a **ClusterIP** Service, serving the UI
and API on container port `8080`. The container entrypoint is
`perses --config=/etc/perses/config.yaml`; the image ships a minimal config that
uses a **file datastore** (no external database), so the chart boots with sane
defaults and needs no ConfigMap. `extraArgs` are appended to that command.

Because the root filesystem is read-only, the chart mounts two writable volumes
for the paths Perses writes to:

- the **file datastore at `/perses`** (dashboards, projects) — controlled by
  `persistence`. Off by default, so it is an `emptyDir` and does not survive a
  restart; enable `persistence` for a PVC to keep state.
- the **plugin cache at `/etc/perses/plugins`**, where the bundled plugin
  archives are unpacked on boot — an always-on ephemeral `emptyDir`, rebuilt on
  each start.

The default topology is **single replica** (`replicaCount: 1`). The file
datastore is per-pod, so scaling out — whether by raising `replicaCount` or
enabling `autoscaling` (HPA on CPU) — is only safe with a shared datastore
backend; leave it at one replica for the default file store. The container runs
nonroot on a read-only root filesystem with all capabilities dropped.

## Configuration examples

Persistent datastore on a named storage class:

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
```

Mount your own Perses config and point the entrypoint at it, keeping the
read-only root filesystem intact:

```yaml
extraArgs:
  - --config=/config/config.yaml
extraVolumes:
  - name: perses-config
    configMap:
      name: my-perses-config
extraVolumeMounts:
  - name: perses-config
    mountPath: /config
    readOnly: true
```

## Uninstall

```bash
helm uninstall dash
```

A PVC provisioned with `persistence.enabled=true` is retained by Kubernetes on
uninstall — delete it explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=dash
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. With the default file datastore, keep a single replica; a
horizontally scaled topology needs a shared datastore backend wired through the
Perses config before enabling `autoscaling`. Perses is Apache-2.0 licensed.

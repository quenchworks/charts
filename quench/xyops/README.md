# Quenchworks xyOps

Hardened [xyOps](https://github.com/pixlcore/xyops) — a complete
workflow-automation and server-monitoring system (job scheduler, host/service
monitors, alerting and ticketing) by Joseph Huckaby, the creator of Cronicle — on a
minimal, nonroot, 0-CVE image pinned by digest. It serves the web UI and JSON API
on port 5522, running on a read-only root filesystem with all capabilities dropped.
The image is cosign-signed (keyless / Sigstore) and the chart pins it by the signed
digest, never a tag. All state lives in an **embedded better-sqlite3 database**, so
there is no external database to run. Licensed **BSD-3-Clause**.

## Install

```bash
helm install xyops oci://ghcr.io/quenchworks/charts/xyops
```

The server runs nonroot on container port 5522; the Service exposes the same port.
Reach the UI and API over a port-forward:

```bash
kubectl port-forward svc/xyops-xyops 5522:5522
curl http://127.0.0.1:5522/api/app/ping
# then browse http://127.0.0.1:5522/
```

xyOps requires a non-empty `secret_key` to boot — it signs sessions and API tokens
with it. Leave `auth` unset and the chart generates a random key on first install
and preserves it across upgrades, or pin your own:

```bash
helm install xyops oci://ghcr.io/quenchworks/charts/xyops \
  --set auth.existingSecret=my-xyops-secret \
  --set auth.existingSecretKey=secret-key
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/xyops \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/xyops \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/xyops` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `auth.secretKey` | `""` | Pin the signing key. Random if empty (preserved across upgrades). |
| `auth.existingSecret` | `""` | Read the signing key from your own Secret; wins over `auth.secretKey`. |
| `auth.existingSecretKey` | `secret-key` | Key within `existingSecret`. |
| `resources.requests` | `100m / 256Mi` | CPU / memory requests. Raise for more monitored hosts/jobs. |
| `resources.limits` | `1 / 1Gi` | CPU / memory limits. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/opt/xyops/data` (the sqlite store). When `false`, uses an `emptyDir` (all state is lost on restart). |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `5522` | Web UI + JSON API port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | NetworkPolicy is the trust boundary. |
| `networkPolicy.allowExternal` | `true` | The UI is commonly reached via Ingress or cluster-wide; set `false` to restrict ingress to the namespace. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

xyOps runs as a single-replica **StatefulSet** (`replicas: 1`) so the embedded
sqlite store keeps a stable identity and its own persistent volume. The container
serves the web UI and JSON API on container port **5522**; the Service maps the
same port. All three probes `httpGet /api/app/ping`, which returns 200 once
pixl-server has started its web listener and opened the sqlite store. The native
better-sqlite3 module plus storage init make the first boot a little slow, so a
startup probe (`failureThreshold: 30`) guards the slow start and liveness/readiness
carry generous timing so a slow node or large image pull does not flap.

Four volumes are mounted, because the root filesystem is read-only:

- **`/opt/xyops/data`** — the embedded sqlite store, backed by the PVC (a
  `volumeClaimTemplate`, or `persistence.existingClaim`). The server only starts if
  it can write here. With `persistence.enabled=false` it falls back to an `emptyDir`
  and all state is lost on restart.
- **`/opt/xyops/logs`** and **`/opt/xyops/temp`** — writable `emptyDir`s for the
  logs and temp files xyOps writes at runtime.
- **`/tmp`** — a writable `emptyDir` for scratch space.

The signing `secret_key` reaches the container as the `XYOPS_secret_key` env var,
read from a Secret (chart-managed, or your own `auth.existingSecret`). Nothing
secret is baked into the image. The hardened pod security context (`fsGroup: 1001`)
gives the nonroot user (uid 1001) ownership of the data volume. The embedded sqlite
store is single-writer, so this is a single-instance workload — do not raise the
replica count.

## Configuration examples

Set the external base URL and pin the signing key from your own Secret:

```yaml
auth:
  existingSecret: my-xyops-secret
  existingSecretKey: secret-key
extraEnvVars:
  - name: XYOPS_base_app_url
    value: "https://xyops.example.com"
```

Every xyOps config setting is overridable at runtime with an `XYOPS_<key>` env var
(pixl-config env override) via `extraEnvVars`. Grow the data volume as monitoring
history accumulates:

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
resources:
  requests: { cpu: 250m, memory: 512Mi }
  limits: { cpu: "2", memory: 2Gi }
```

## Uninstall

```bash
helm uninstall xyops
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the sqlite store gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=xyops
```

The chart-generated signing Secret is also retained; delete it too if you are done
with the release.

## Notes

Single-instance by design — the embedded better-sqlite3 store does not support
horizontal scaling, so the StatefulSet is fixed at one replica; there is no
external database. The
chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the server is
pinned by digest. xyOps has its own user accounts and login — keep the NetworkPolicy
as the trust boundary and front it with TLS before exposing the UI beyond the
cluster.

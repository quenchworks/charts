# Quenchworks rqlite

Hardened [rqlite](https://github.com/rqlite/rqlite) — a lightweight distributed
relational database built on SQLite with Raft consensus — on a minimal, nonroot,
0-CVE image pinned by digest. It serves the HTTP API on port 4001 and Raft on
port 4002, running on a read-only root filesystem with all capabilities dropped.
The image is cosign-signed (keyless / Sigstore) and the chart pins it by the
signed digest, never a tag.

## Install

```bash
helm install my-rqlite oci://ghcr.io/quenchworks/charts/rqlite
```

Size the data volume and pick a storage class:

```bash
helm install my-rqlite oci://ghcr.io/quenchworks/charts/rqlite \
  --set persistence.size=20Gi \
  --set persistence.storageClass=fast-ssd
```

The HTTP API is often reached from outside the cluster. To allow ingress from any
source (default restricts it to the release namespace):

```bash
helm install my-rqlite oci://ghcr.io/quenchworks/charts/rqlite \
  --set networkPolicy.allowExternal=true
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rqlite \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/rqlite \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/rqlite` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | StatefulSet replicas. Single-node today; see Architecture. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/data`. When `false`, uses an `emptyDir` (data is lost on restart). |
| `persistence.size` | `8Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.httpPort` | `4001` | rqlite HTTP API port. |
| `service.raftPort` | `4002` | Raft inter-node port. |
| `resources.requests` | `100m / 128Mi` | CPU / memory requests. |
| `resources.limits` | `500m / 256Mi` | CPU / memory limits. |
| `command` | `[]` | Override the entrypoint (default `/usr/bin/rqlited`). |
| `args` | `[]` | Override server args (e.g. clustering, auth). Empty uses the hardened defaults. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts HTTP ingress to the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow HTTP ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

rqlite runs as a **StatefulSet** so each node keeps a stable network identity and
its own persistent volume. State lives in a single volume mounted at `/data` (the
baked-in `/rqlite/data` sits under the image's read-only WORKDIR, so the chart
points rqlited at the writable mount instead). Persistence provisions one PVC per
replica via a `volumeClaimTemplate`; with `persistence.enabled=false` the data
dir is an `emptyDir` and does not survive a restart.

Two ports are exposed: **HTTP (4001)** for the SQL API and **Raft (4002)** for
inter-node consensus. Each node advertises itself over its stable headless DNS
name (`<pod>.<headless>.<ns>.svc.cluster.local`) rather than `0.0.0.0`, which
rqlited rejects as non-routable — this is also what lets future peers find each
other. Probes: a TCP liveness check on the HTTP port and an HTTP readiness check
against `/readyz`.

The default topology is **single-node** (`replicaCount: 1`). A clustered, Raft
consensus topology needs `-bootstrap-expect` / `-join` peer discovery wired
through the `args` override and is not yet a first-class chart feature — keep
`replicaCount` at 1 unless you supply your own clustering args (see below).

## Configuration examples

Single node with a larger volume on a named storage class:

```yaml
replicaCount: 1
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
```

Advanced multi-node cluster (overrides the baked args to add Raft bootstrap
discovery; the per-pod headless advertise addresses must be reproduced). This is
not yet officially supported — validate carefully before relying on it:

```yaml
replicaCount: 3
args:
  - -http-addr=0.0.0.0:4001
  - -http-adv-addr=$(POD_NAME).my-rqlite-headless.$(POD_NAMESPACE).svc.cluster.local:4001
  - -raft-addr=0.0.0.0:4002
  - -raft-adv-addr=$(POD_NAME).my-rqlite-headless.$(POD_NAMESPACE).svc.cluster.local:4002
  - -bootstrap-expect=3
  - -join=my-rqlite-0.my-rqlite-headless.$(POD_NAMESPACE).svc.cluster.local:4002
  - /data
```

## Uninstall

```bash
helm uninstall my-rqlite
```

PVCs provisioned by the `volumeClaimTemplate` are retained by Kubernetes on
uninstall — delete them explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-rqlite
```

## Notes

Single node for now; a Raft-clustered multi-node topology (first-class `-join` /
peer discovery over the headless service) and HTTP API auth are tracked
follow-ups. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the server is
pinned by digest.

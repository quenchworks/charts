# Quenchworks zot

Hardened [zot](https://github.com/project-zot/zot) — a production-ready,
vendor-neutral, OCI-native container image registry — on a minimal, nonroot,
0-CVE image pinned by digest. It serves the OCI Distribution API on port 5000,
running on a read-only root filesystem with all capabilities dropped. The image
is cosign-signed (keyless / Sigstore) and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install my-zot oci://ghcr.io/quenchworks/charts/zot
```

Size the blob store and pick a storage class:

```bash
helm install my-zot oci://ghcr.io/quenchworks/charts/zot \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd
```

To manage the registry config yourself (auth, TLS, S3-backed storage), point at
an externally-managed ConfigMap with a `config.json` key:

```bash
helm install my-zot oci://ghcr.io/quenchworks/charts/zot \
  --set config.existingConfigMap=my-zot-config
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/zot \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/zot \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/zot` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | StatefulSet replicas. Keep at 1 unless using shared (S3) storage. |
| `config.configJson` | filesystem, `:5000` | Full zot `config.json`, rendered into a ConfigMap and mounted over `/etc/zot`. |
| `config.existingConfigMap` | `""` | Use an externally-managed ConfigMap (key `config.json`) instead. |
| `persistence.enabled` | `true` | 10Gi PVC mounted at `/var/lib/registry`. When `false`, uses an `emptyDir` (blobs are lost on restart). |
| `persistence.size` | `10Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `5000` | The registry HTTP API. |
| `resources.requests` | `100m / 128Mi` | CPU / memory requests. |
| `resources.limits` | `1 / 512Mi` | CPU / memory limits. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | NetworkPolicy is the trust boundary. |
| `networkPolicy.allowExternal` | `true` | A registry is commonly pulled/pushed cluster-wide; set `false` to restrict ingress to the namespace. |
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

zot runs as a **StatefulSet** so the blob store keeps a stable identity and its
own persistent volume. The container serves the OCI Distribution API on port
**5000**; both liveness and readiness probe `GET /v2/`, which returns 200 once
the registry is ready.

Three volumes are mounted, because the root filesystem is read-only:

- **`/var/lib/registry`** — the blob/manifest store, backed by the PVC (a
  `volumeClaimTemplate`, or `persistence.existingClaim`). With
  `persistence.enabled=false` it falls back to an `emptyDir`.
- **`/etc/zot`** — the config, mounted read-only from a ConfigMap over the
  image default. The image runs `zot serve /etc/zot/config.json`.
- **`/tmp`** — a writable `emptyDir` for scratch space.

Config is the main lever. The chart renders `config.configJson` into a ConfigMap;
the default declares dist-spec `1.1.1`, filesystem storage rooted at
`/var/lib/registry`, and the HTTP listener on `0.0.0.0:5000`. Editing this JSON
is how you enable htpasswd/OIDC auth, TLS, or S3-backed storage. Scaling past one
replica requires shared storage (S3) configured in `config.configJson`, since the
default filesystem store is single-writer.

## Configuration examples

Persistent registry with htpasswd basic auth (mount the htpasswd file via
`extraVolumes`/`extraVolumeMounts`, then reference it in the config):

```yaml
persistence:
  enabled: true
  size: 50Gi
config:
  configJson: |
    {
      "distSpecVersion": "1.1.1",
      "storage": { "rootDirectory": "/var/lib/registry" },
      "http": {
        "address": "0.0.0.0",
        "port": "5000",
        "auth": { "htpasswd": { "path": "/secret/htpasswd" } }
      },
      "log": { "level": "info" }
    }
extraVolumes:
  - name: htpasswd
    secret:
      secretName: my-zot-htpasswd
extraVolumeMounts:
  - name: htpasswd
    mountPath: /secret
    readOnly: true
```

S3-backed storage for scale-out (blobs move off the PVC; set credentials via
`extraEnvVars`):

```yaml
config:
  configJson: |
    {
      "distSpecVersion": "1.1.1",
      "storage": {
        "rootDirectory": "/var/lib/registry",
        "storageDriver": {
          "name": "s3",
          "region": "us-east-1",
          "bucket": "my-registry",
          "rootdirectory": "/zot"
        }
      },
      "http": { "address": "0.0.0.0", "port": "5000" },
      "log": { "level": "info" }
    }
```

## Uninstall

```bash
helm uninstall my-zot
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the blob store gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-zot
```

## Notes

Single filesystem-backed replica by default; multi-replica scale-out needs S3
(or another shared driver) wired through `config.configJson`. The chart depends
on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the registry is
pinned by digest.

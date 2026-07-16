# Quenchworks Ollama

Hardened [Ollama](https://github.com/ollama/ollama) — the local
large-language-model runtime that pulls open models (Llama, Mistral, Gemma,
Qwen, ...) and serves them over a simple REST API — on a minimal, nonroot,
0-CVE image pinned by digest. This is the **CPU-only** image (GPU acceleration
is out of scope for this chart); it runs as a single-replica StatefulSet with a
persistent `/models` volume and serves the inference API on port 11434, on a
read-only root filesystem with all capabilities dropped. The image is
cosign-signed (keyless / Sigstore) and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install ollama oci://ghcr.io/quenchworks/charts/ollama
```

LLM serving is memory-hungry — the working set scales with the model you pull
(a 7B model needs several GiB of RAM). Size the `/models` volume and raise the
resource limits to fit the models you intend to run:

```bash
helm install ollama oci://ghcr.io/quenchworks/charts/ollama \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd \
  --set resources.limits.memory=8Gi
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ollama \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/ollama --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ollama` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. Signed multi-arch index. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `resources.requests` | `cpu 250m / mem 512Mi` | Deliberately modest so the chart schedules anywhere; raise to fit your models. |
| `resources.limits` | `cpu 2 / mem 4Gi` | Raise for larger models. |
| `persistence.enabled` | `true` | `/models` PVC via a `volumeClaimTemplate`. When `false`, uses an `emptyDir` (models are lost on restart). |
| `persistence.size` | `20Gi` | Sized for a few models; grow as needed. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `11434` | Inference REST API. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | NetworkPolicy on ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
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

Ollama keeps pulled models on disk, so this is a **stateful** workload. The
chart runs a single-replica StatefulSet behind a ClusterIP Service and mounts a
persistent volume at `/models` (`OLLAMA_MODELS`) via a `volumeClaimTemplate`, so
pulled models survive restarts. With `persistence.enabled=false` the models dir
is an `emptyDir` and does not survive a restart.

The image already bakes in `OLLAMA_MODELS=/models` and
`OLLAMA_HOST=0.0.0.0:11434` and starts `ollama serve`; the Service maps the same
port 11434. The read-only rootfs is paired with a writable `emptyDir` at `/tmp`.
The server only starts if it can write `/models`, so the hardened pod security
context (`fsGroup: 1001`) gives the nonroot user (uid 1001) ownership of the
volume. Every container runs nonroot on a read-only root filesystem with all
capabilities dropped.

## Configuration examples

No model ships with the chart (models are gigabytes). Pull one into the
persistent `/models` volume by exec-ing into the StatefulSet pod, then query the
API over a port-forward:

```bash
kubectl exec -it ollama-ollama-0 -- ollama pull llama3.2
kubectl port-forward svc/ollama-ollama 11434:11434
curl http://127.0.0.1:11434/api/version
curl http://127.0.0.1:11434/api/tags
curl http://127.0.0.1:11434/api/generate -d '{"model":"llama3.2","prompt":"hi","stream":false}'
```

Tune how long a model stays resident in memory after its last request via
`extraEnvVars`:

```yaml
extraEnvVars:
  - name: OLLAMA_KEEP_ALIVE
    value: "5m"
```

Larger volume on a named storage class, with limits raised to fit a bigger
model:

```yaml
persistence:
  enabled: true
  size: 50Gi
  storageClass: fast-ssd
resources:
  limits:
    cpu: "4"
    memory: 8Gi
```

## Uninstall

```bash
helm uninstall ollama
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the pulled models gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=ollama
```

## Notes

CPU-only; GPU acceleration is out of scope for this chart. The chart depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. The inference API serves without authentication — keep the
NetworkPolicy as the trust boundary before exposing it beyond the cluster.

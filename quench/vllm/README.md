# Quenchworks vLLM

Hardened [vLLM](https://github.com/vllm-project/vllm) — a high-throughput
inference and serving engine for open LLMs that exposes an **OpenAI-compatible**
REST API — on a minimal, nonroot, 0-CVE image pinned by digest. It serves the API
on port 8000, running on a read-only root filesystem with all capabilities
dropped. The image is cosign-signed (keyless / Sigstore) and the chart pins it by
the signed digest, never a tag. This is the **CPU-only** image; GPU acceleration is
out of scope for this chart, and CPU inference wants an avx512f/avx2 host CPU.

## Install

No model ships with the chart — weights are gigabytes. You **must** set `model` to
a Hugging Face model id or a mounted path, or the server has nothing to serve and
the pod crash-loops:

```bash
helm install vllm oci://ghcr.io/quenchworks/charts/vllm \
  --set model=Qwen/Qwen2.5-0.5B-Instruct
```

The server runs nonroot on container port 8000; the Service exposes the same port.
Reach the OpenAI-compatible API over a port-forward:

```bash
kubectl port-forward svc/vllm-vllm 8000:8000
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models
curl http://127.0.0.1:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-0.5B-Instruct","prompt":"hello","max_tokens":16}'
```

Size the model cache and pick a storage class:

```bash
helm install vllm oci://ghcr.io/quenchworks/charts/vllm \
  --set model=Qwen/Qwen2.5-0.5B-Instruct \
  --set persistence.size=60Gi \
  --set persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vllm \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/vllm \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/vllm` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `model` | `""` | **Required** — HF model id or a mounted path. Empty means the pod crash-loops. |
| `extraArgs` | `[]` | Extra flags appended to `vllm serve <model> --host 0.0.0.0 --port 8000` (e.g. `--max-model-len=4096`, `--dtype=bfloat16`). |
| `resources.requests` | `500m / 2Gi` | CPU / memory requests. Raise to fit your model. |
| `resources.limits` | `4 / 8Gi` | CPU / memory limits. A 7B model in bf16 needs ~16Gi. |
| `persistence.enabled` | `true` | 30Gi PVC mounted at `/opt/vllm/.cache` (the HF cache). When `false`, uses an `emptyDir` (weights are re-downloaded on restart). |
| `persistence.size` | `30Gi` | Requested volume size. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.annotations` | `{}` | Annotations on the PVC template. |
| `persistence.selector` | `{}` | Bind to a matching PV by selector. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8000` | OpenAI-compatible API port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `serviceAccount.annotations` | `{}` | Annotations on the ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | NetworkPolicy is the trust boundary. |
| `networkPolicy.allowExternal` | `true` | The inference API is commonly consulted cluster-wide; set `false` to restrict ingress to the namespace. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `args`, `podSecurityContext`,
`containerSecurityContext`, and the probe overrides (`livenessProbe`,
`readinessProbe`, `startupProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

vLLM runs as a single-replica **StatefulSet** (`replicas: 1`) so the model cache
keeps a stable identity and its own persistent volume. The image entrypoint is
`/usr/bin/vllm`; the chart supplies `serve <model> --host 0.0.0.0 --port 8000`
(plus any `extraArgs`), which starts the OpenAI-compatible server on container port
**8000**. The Service maps the same port.

Two volumes are mounted, because the root filesystem is read-only:

- **`/opt/vllm/.cache`** — the Hugging Face cache (`HF_HOME`/`XDG_CACHE_HOME`,
  baked into the image), backed by the PVC (a `volumeClaimTemplate`, or
  `persistence.existingClaim`). With `persistence.enabled=false` it falls back to
  an `emptyDir` and weights are re-downloaded on restart. `HOME` is pointed at this
  volume too, so stray dotfile writes (HF token, torch/triton caches) land on it.
- **`/tmp`** — a writable `emptyDir` for scratch space.

All three probes `httpGet /health`, which returns 200 once the model is loaded and
the engine is ready. Model load is slow, so the startup probe carries a generous
`failureThreshold` (60 × 10s, up to ~10 min) and liveness/readiness only begin once
it first succeeds. The hardened pod security context (`fsGroup: 1001`) gives the
nonroot user (uid 1001) ownership of the cache volume.

CPU inference is **memory-heavy**: the working set is dominated by the model weights
(a 7B model in bf16 needs ~16Gi RAM) plus the KV cache, which scales with
`--max-model-len` and concurrency. The defaults are deliberately modest so the chart
schedules on a typical node and the model-less CI gate passes — raise `resources` to
fit your model and cap context with `--max-model-len` on CPU.

## Configuration examples

Serve a small model with a capped context and a larger cache on a named storage
class:

```yaml
model: Qwen/Qwen2.5-0.5B-Instruct
extraArgs:
  - --max-model-len=4096
  - --dtype=bfloat16
persistence:
  enabled: true
  size: 60Gi
  storageClass: fast-ssd
resources:
  requests: { cpu: "1", memory: 4Gi }
  limits: { cpu: "8", memory: 16Gi }
```

Pull a gated model with a Hugging Face token and give the KV cache more room:

```yaml
model: meta-llama/Llama-3.2-1B-Instruct
extraEnvVars:
  - name: HF_TOKEN
    value: "hf_..."
  - name: VLLM_CPU_KVCACHE_SPACE
    value: "4"
```

## Uninstall

```bash
helm uninstall vllm
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the cached weights gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=vllm
```

## Notes

CPU-only and single-replica by default; GPU acceleration is out of scope for this
chart. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the server is
pinned by digest. The OpenAI-compatible API is served without authentication —
keep the NetworkPolicy as the trust boundary and front it with your own auth before
exposing it beyond the cluster.

# Quenchworks vLLM

Hardened [vLLM](https://github.com/vllm-project/vllm) on a minimal, nonroot,
read-only-rootfs, 0-CVE image, pinned by digest and cosign-signed.

vLLM is a high-throughput inference/serving engine for open LLMs that exposes an
**OpenAI-compatible** REST API. This is the **CPU-only** image — GPU acceleration
is out of scope for this chart. CPU inference wants an avx512f/avx2 host CPU.

## Install

No model ships with the chart (weights are gigabytes). You **must** set `model` to
a Hugging Face model id or a mounted path:

```sh
helm install vllm oci://ghcr.io/quenchworks/charts/vllm \
  --set model=Qwen/Qwen2.5-0.5B-Instruct
```

Left unset, the server has nothing to serve and the pod crash-loops. The server
runs nonroot and serves the OpenAI-compatible API on container port 8000; the
Service exposes it on the same port.

## Querying the API

```sh
kubectl port-forward svc/vllm-vllm 8000:8000
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models
curl http://127.0.0.1:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-0.5B-Instruct","prompt":"hello","max_tokens":16}'
```

## Storage

This is a stateful workload. The chart runs a single-replica **StatefulSet** and
mounts a persistent volume at `/opt/vllm/.cache` (`HF_HOME`) via a
`volumeClaimTemplate`, so downloaded model weights survive restarts. The read-only
rootfs is paired with a writable `emptyDir` at `/tmp`, and `HOME` points at the
cache volume so stray dotfile writes stay on it. The hardened pod security context
(`fsGroup: 1001`) gives the nonroot user (uid 1001) ownership of the volume.

## Resources

CPU inference is **memory-heavy**: the working set is dominated by model weights (a
7B model in bf16 needs ~16Gi RAM) plus the KV cache (scales with `--max-model-len`
and concurrency). Defaults are modest so the chart schedules and the CI gate passes;
raise `resources` to fit your model and cap context with `--max-model-len` on CPU.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `model` | `""` | **required** — HF model id or mounted path; empty = crash-loop |
| `extraArgs` | `[]` | extra `vllm serve` flags, e.g. `--max-model-len=4096`, `--dtype=bfloat16` |
| `image.repository` | `ghcr.io/quenchworks/images/vllm` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `resources.requests` | `cpu 500m / memory 2Gi` | raise to fit your model |
| `resources.limits` | `cpu 4 / memory 8Gi` | a 7B model in bf16 needs ~16Gi |
| `persistence.enabled` | `true` | HF cache PVC; `false` uses an ephemeral emptyDir |
| `persistence.size` | `30Gi` | sized for a model or two; grow as needed |
| `persistence.storageClass` | `""` | default class if unset |
| `persistence.existingClaim` | `""` | bind an existing PVC instead of provisioning one |
| `extraEnvVars` | `[]` | e.g. `HF_TOKEN` for gated models, `VLLM_CPU_KVCACHE_SPACE` |
| `service.type` | `ClusterIP` | |
| `service.port` | `8000` | OpenAI-compatible API |

# Quenchworks Ollama

Hardened [Ollama](https://github.com/ollama/ollama) on a minimal, nonroot,
read-only-rootfs, 0-CVE image, pinned by digest and cosign-signed.

Ollama is a local LLM runtime: it pulls open models (Llama, Mistral, Gemma, Qwen,
...) and serves them over a simple REST API. This is the **CPU-only** image — GPU
acceleration is out of scope for this chart.

## Install

```sh
helm install ollama oci://ghcr.io/quenchworks/charts/ollama
```

The server runs nonroot and serves the inference API on container port 11434; the
Service exposes it on the same port.

## Pulling models

No model ships with the chart (models are gigabytes). Pull one into the persistent
`/models` volume by exec-ing into the StatefulSet pod, then query the API over a
port-forward:

```sh
kubectl exec -it ollama-ollama-0 -- ollama pull llama3.2
kubectl port-forward svc/ollama-ollama 11434:11434
curl http://127.0.0.1:11434/api/version
curl http://127.0.0.1:11434/api/tags
curl http://127.0.0.1:11434/api/generate -d '{"model":"llama3.2","prompt":"hi","stream":false}'
```

## Storage

This is a stateful workload. The chart runs a single-replica **StatefulSet** and
mounts a persistent volume at `/models` (`OLLAMA_MODELS`) via a
`volumeClaimTemplate`, so pulled models survive restarts. The read-only rootfs is
paired with a writable `emptyDir` at `/tmp`. The server only starts if it can write
`/models`; the hardened pod security context (`fsGroup: 1001`) gives the nonroot
user (uid 1001) ownership of the volume.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ollama` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `resources.requests` | `cpu 250m / memory 512Mi` | raise to fit your models (a 7B model needs several GiB RAM) |
| `resources.limits` | `cpu 2 / memory 4Gi` | raise for larger models |
| `persistence.enabled` | `true` | `/models` PVC; `false` uses an ephemeral emptyDir |
| `persistence.size` | `20Gi` | sized for a few models; grow as needed |
| `persistence.storageClass` | `""` | default class if unset |
| `persistence.existingClaim` | `""` | bind an existing PVC instead of provisioning one |
| `extraEnvVars` | `[]` | e.g. `OLLAMA_KEEP_ALIVE` to tune model residency |
| `service.type` | `ClusterIP` | |
| `service.port` | `11434` | inference API |

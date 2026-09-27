# Quenchworks llm-stack

A self-hosted LLM backend in one install, from QuenchWorks images (nonroot, 0
fixable CVEs, pinned by digest, cosign-signed):

| Component | Chart | Role |
|---|---|---|
| Ollama | `ollama` | runs the models (CPU) |
| LiteLLM | `litellm` | one OpenAI-compatible API in front of them, with a generated key |
| Qdrant | `qdrant` | vector database for retrieval (RAG) |

A Job pulls the models in `models` into Ollama after install, and LiteLLM's
`model_list` already routes the names `embed` and `chat` to them.

## Install

```bash
helm install llm oci://ghcr.io/quenchworks/charts/llm-stack
KEY=$(kubectl get secret llm-litellm-master-key -o jsonpath='{.data.master-key}' | base64 -d)
kubectl port-forward svc/llm-litellm 4000:4000 &
curl -s http://127.0.0.1:4000/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"chat","messages":[{"role":"user","content":"Say hi"}]}'
```

Names are fixed (`llm-ollama`, `llm-litellm`, `llm-qdrant`), so run one stack
per namespace.

## Values

| Key | Default | Notes |
|---|---|---|
| `models` | `[all-minilm, qwen2.5:0.5b]` | pulled into Ollama by the install Job |
| `litellm.config.model_list` | `embed`, `chat` | names clients use, routed to Ollama |
| `modelPull.enabled` | `true` | the pull Job |
| `ollama.persistence.size` | `20Gi` | where the models live |

To serve another model, add it to `models` and give it an entry in
`litellm.config.model_list` (`ollama/<name>` for embeddings, `ollama_chat/<name>`
for chat).

## Notes

- Ollama here is CPU-only. The default models are small, for trying the stack
  out; larger ones need the node memory to match.
- Qdrant runs without an API key; its NetworkPolicy admits only pods in the
  same namespace. Set `qdrant.auth.apiKey` before opening it wider.
- LiteLLM keeps no database here, so its virtual keys and spend tracking are
  off; the master key is the only credential.

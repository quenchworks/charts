# LiteLLM

[LiteLLM](https://www.litellm.ai) is a proxy that puts one OpenAI-compatible API in front
of 100+ LLM providers (OpenAI, Anthropic, Bedrock, Azure, Vertex, Ollama, vLLM, ...), with
routing, fallbacks, virtual keys, budgets and spend logging.

This chart runs the QuenchWorks LiteLLM image: an **MIT-only build**. LiteLLM's PyPI
`proxy` extra pins `litellm-enterprise`, which is proprietary; the image installs every
other proxy dependency and leaves that package out, so enterprise features (SSO, audit
logs and other paid features) are off. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install litellm oci://ghcr.io/quenchworks/charts/litellm \
  --set extraEnvVarsSecret=llm-provider-keys \
  -f my-models.yaml
```

with `my-models.yaml`:

```yaml
config:
  model_list:
    - model_name: gpt-4o
      litellm_params:
        model: openai/gpt-4o
        api_key: os.environ/OPENAI_API_KEY
```

The master key (`LITELLM_MASTER_KEY`) is generated on first install as `sk-...`, stored
in the `<release>-litellm-master-key` Secret, and kept across upgrades. Bring your own
with `masterKey.existingSecret`.

```sh
KEY=$(kubectl get secret litellm-master-key -o jsonpath='{.data.master-key}' | base64 -d)
kubectl port-forward svc/litellm 4000:4000
curl -H "Authorization: Bearer $KEY" http://127.0.0.1:4000/v1/models
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `config` | empty model list | the proxy `config.yaml` (models, router, general settings) |
| `masterKey.existingSecret` | `""` | Secret with the master key; empty generates one |
| `database.existingSecret` | `""` | Secret with `DATABASE_URL` (PostgreSQL) for keys, teams and spend |
| `extraEnvVarsSecret` | `""` | provider API keys, referenced in the config as `os.environ/NAME` |
| `numWorkers` | `""` | uvicorn workers per pod |
| `service.port` | `4000` | API port |

The pod runs with a read-only root filesystem, all capabilities dropped, and emptyDir
volumes for `/tmp` and the home directory. Config changes roll the Deployment.

The release gate installs the chart on kind, checks `/health/liveliness`, requires HTTP
401 from `/v1/models` without a key, and requires the configured model in the list with
the generated key.

The chart depends on the `quench-common` library chart from
`oci://ghcr.io/quenchworks/charts`.

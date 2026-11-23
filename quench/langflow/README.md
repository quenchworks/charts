# Langflow

[Langflow](https://github.com/langflow-ai/langflow) is a visual builder for LLM applications and agent workflows:
compose flows from components (models, prompts, tools, vector stores) in a React UI and run them through the REST
API. The image is built by QuenchWorks from the 1.13.3 tag, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install langflow oci://ghcr.io/quenchworks/charts/langflow
kubectl port-forward svc/langflow 7860:7860
```

Log in as `admin`. The password is generated once and kept in the release Secret:

```sh
kubectl get secret langflow -o jsonpath='{.data.admin-password}' | base64 -d
```

## How it runs

- Auto-login is off (Langflow 1.13's default): the chart creates the superuser from the Secret, and new sign-ups
  stay inactive until the superuser activates them.
- Flows, users and variables live in the bundled PostgreSQL. `/home/langflow` (the config dir, caches and uploaded
  files) is on a PVC. One replica; updates stop the old pod first.
- `secret-key` in the release Secret encrypts the credentials stored in flows (provider API keys). It is generated
  once and kept on upgrade; losing it makes those credentials unreadable, so back up the Secret.
- Model provider keys: put them in a Secret and add it with `extraEnvVarsSecret` (e.g. `OPENAI_API_KEY`), or store
  them as global variables in the UI.

## Image notes

- The image takes Wolfi's builds of 36 compiled Python dependencies (psycopg2 instead of psycopg2-binary, pyarrow,
  numpy, pydantic-core, grpcio ...), rebuilds the Rust extensions that hide their crates with `cargo auditable`
  (pyo3 0.29 for fastuuid and watchfiles; litellm's Rust bridge on rustls 0.23), and fails the build if any other
  wheel ships its own native libraries.
- The IBM watsonx/DB2 bundle (`lfx-ibm`) is left out: `ibm_db` ships a DB2 client with its own crypto libraries.
- pydantic is allowed up to 2.14 (upstream caps at <2.14), so pydantic-core comes from Wolfi.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.username` | `admin` | The superuser. |
| `admin.password` | generated | Kept in the Secret (`admin-password`). |
| `secret.existingSecret` | `""` | Your own Secret with `admin-password` and `secret-key`. |
| `env` | `{}` | Extra `LANGFLOW_*` settings, e.g. `LANGFLOW_LOG_LEVEL: info`. |
| `postgresql.enabled` | `true` | The bundled PostgreSQL. Off: set `externalDatabase.*` with `existingSecret`. |
| `persistence.size` | `10Gi` | `/home/langflow`. |
| `resources` | 250m / 1Gi requests, 2 / 4Gi limits | |
| `service.port` | `7860` | |
| `ingress.*` | off | |

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/langflow \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

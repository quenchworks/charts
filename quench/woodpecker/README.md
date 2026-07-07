# Quenchworks woodpecker

Hardened [Woodpecker CI](https://woodpecker-ci.org/) **server** on a minimal,
nonroot, 0-CVE image pinned by digest. Single node; persists its SQLite DB to a
PVC. Serves the web UI/API over HTTP and accepts agent connections over gRPC.

> This chart ships the Woodpecker **server** only. Agents are deployed and scaled
> separately and authenticate with the shared `WOODPECKER_AGENT_SECRET`.

## Install

Woodpecker requires a forge (GitHub / Gitea / GitLab / Bitbucket) to start. Set
your forge, public host, and a stable agent secret:

```bash
helm install my-woodpecker oci://ghcr.io/quenchworks/charts/woodpecker \
  --set host=https://ci.example.com \
  --set agentSecret.value=$(openssl rand -hex 32) \
  --set-string extraEnvVars[0].name=WOODPECKER_GITHUB \
  --set-string extraEnvVars[0].value=true \
  --set-string extraEnvVars[1].name=WOODPECKER_GITHUB_CLIENT \
  --set-string extraEnvVars[1].value=<oauth-client-id> \
  --set extraEnvVarsSecret=woodpecker-forge   # holds WOODPECKER_GITHUB_SECRET
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-woodpecker-woodpecker 8000:80
# http://127.0.0.1:8000
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/woodpecker \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/woodpecker` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (SQLite); do not scale out. |
| `containerPort` | `8000` | HTTP (web UI/API). Wired to `WOODPECKER_SERVER_ADDR`. |
| `grpcPort` | `9000` | gRPC for agents. Wired to `WOODPECKER_GRPC_ADDR`. |
| `host` | `""` | `WOODPECKER_HOST` — public server URL. **Required** in production. |
| `agentSecret.value` | `""` | Fixed `WOODPECKER_AGENT_SECRET`; creates a Secret. Rotate in prod. |
| `agentSecret.existingSecret` | `""` | Use an existing Secret instead. |
| `agentSecret.existingSecretKey` | `WOODPECKER_AGENT_SECRET` | Key within that Secret. |
| `service.port` | `80` | HTTP Service port -> container `http`. |
| `service.grpcPort` | `9000` | gRPC Service port -> container `grpc`. |
| `persistence.enabled` | `true` | 2Gi PVC mounted at `/var/lib/woodpecker` (SQLite DB). |
| `persistence.size` | `2Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `extraEnvVars` | `[]` | Extra `WOODPECKER_*` env; put the forge config here. |
| `extraEnvVarsSecret` | `""` | Secret of env vars (e.g. `WOODPECKER_GITHUB_SECRET`). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | HTTP + gRPC ingress from the namespace; `allowExternal: true` opens it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Configuring a forge

A forge is mandatory — the server will not start without one. Configure it
through `extraEnvVars` (non-secret keys) plus a Secret referenced by
`extraEnvVarsSecret` (client secrets). See the
[Woodpecker forge docs](https://woodpecker-ci.org/docs/administration/forges/overview)
for the full `WOODPECKER_<FORGE>_*` variable set.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the `/var/lib/woodpecker` PVC and an emptyDir `/tmp` are writable.
The server serves `/healthz` (HTTP 204 when up), used for the startup, liveness,
and readiness probes.

## Notes

Single node only: the server stores its state in a local SQLite database, so it
cannot be horizontally scaled. For HA you would need an external database backend
(`WOODPECKER_DATABASE_DRIVER` = `postgres` / `mysql`), tracked as a follow-up.

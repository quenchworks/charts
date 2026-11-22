# Quenchworks PentAGI

Hardened [PentAGI](https://github.com/vxcontrol/pentagi): autonomous AI agents that plan and run penetration tests,
driving their tools (Kali, Debian and other images) in containers through a Docker API. The image builds the Go
server and the React frontend from the release tag on Wolfi, runs as uid 1001 on a read-only root filesystem with
DATA_DIR on a volume, and is CVE-gated at build, cosign-signed and pinned by digest.

The chart runs it on the bundled QuenchWorks PostgreSQL with pgvector, gives it a Docker API from a Podman sidecar,
and can serve native TLS on 8443. Upstream seeds `admin@pentagi.com` with the password `admin`; a post-install Job
replaces it with a generated password before anyone signs in, and never touches a password changed later.

## Install

```bash
helm install pentagi oci://ghcr.io/quenchworks/charts/pentagi -n pentagi --create-namespace \
  --set publicURL=https://pentagi.example.com
```

Sign in as `admin@pentagi.com`; read the password from the chart Secret (see the install notes). Add an LLM provider
key through `extraEnvVarsSecret` (for example `OPEN_AI_KEY` or `ANTHROPIC_API_KEY`) before starting a flow.

## The Docker API sidecar

Every flow starts containers. The default sidecar is Podman's Docker-compatible service, listening on the pod's
loopback only. It runs **privileged as root** (it creates namespaces, cgroups and bridges), so the namespace's Pod
Security admission must allow privileged pods, and the node runs whatever images the agents choose. Images and
containers live on an emptyDir capped by `docker.sidecar.storageSizeLimit`. To use a Docker host of your own
instead, set `docker.sidecar.enabled=false` and `docker.host`.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `publicURL` | `""` | Public URL; restricts `CORS_ORIGINS` to it |
| `adminPassword` | `""` | Generated when empty; set on first install by the bootstrap Job |
| `docker.sidecar.enabled` | `true` | Privileged Podman sidecar serving the Docker API |
| `docker.host` | `""` | Your own Docker API when the sidecar is off |
| `docker.network` | `""` | Network for the tool containers (`DOCKER_NETWORK`) |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` (pgvector; the role creates the vector and pgcrypto extensions) |
| `settings` | `{}` | More settings as environment variables (`LLM_SERVER_URL`, `DOCKER_DEFAULT_IMAGE_FOR_PENTEST`, ...) |
| `tls.enabled` | `false` | HTTPS on 8443 from `tls.existingSecret`, cert-manager, or a Helm-made CA |

PentAGI runs one replica (DATA_DIR on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pentagi \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

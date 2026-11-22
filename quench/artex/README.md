# Quenchworks ARTEX

Hardened [ARTEX](https://github.com/BaaRai/ARTEX): an AI penetration-testing orchestrator that plans and drives
recon and scanning tools (nuclei is bundled) from a web console. **Use it only on systems you are authorized to
test.** The image builds the BaaRai/ARTEX fork from source (the named upstream, Autumn-27/ARTEX, is no longer
public): the Next.js console is exported statically and embedded into the Go binary. It runs as uid 1001 on a
read-only root filesystem and is CVE-gated at build, cosign-signed and pinned by digest.

The agent runs shell commands. The hardened container (nonroot, read-only root filesystem, dropped capabilities)
is the containment boundary; ARTEX's own root-to-user drop is off because a nonroot process cannot change user.

The chart runs on the bundled QuenchWorks PostgreSQL (the schema creates itself) and keeps the data dir, the JWT
and secret keys and the agent's files on a PersistentVolumeClaim.

## Install

```bash
helm install artex oci://ghcr.io/quenchworks/charts/artex
```

While no admin password exists, the server prints a one-time setup token to its log. Read it and enter it with a
password on the `/setup` page, then sign in as user `ARTEX` (the only account):

```bash
kubectl logs deploy/artex | grep 'Setup token'
```

## Configuration

| Value | Default | Notes |
|---|---|---|
| `persistence.size` | `5Gi` | Data, keys and agent files (`/var/lib/artex`) |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` with a Secret holding a URL-safe password |
| `extraEnvVarsSecret` | `""` | Secret with the LLM keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, ...) |
| `settings` | `{}` | More `ARTEX_*` settings (`ARTEX_LLM_PROVIDER`, `ARTEX_LLM_MODEL`, `ARTEX_TRUSTED_PROXIES`) |
| `ingress.*` | off | No TLS listener: terminate TLS here |
| `networkPolicy.enabled` | `true` | Limits ingress to the console; egress stays open for scanning |

ARTEX runs one replica (data on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/artex \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

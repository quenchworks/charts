# Quenchworks OpenBao

Hardened [OpenBao](https://github.com/openbao/openbao) secrets-management server on
a minimal, nonroot, 0-CVE image pinned by digest. OpenBao is the truly-open
**MPL-2.0** fork of HashiCorp Vault (which moved to the BUSL license) — a clean,
OSI-licensed alternative. The `bao` server + Vault-compatible CLI are built from
source on Wolfi. Single-node **raft integrated storage**; the HTTP API is on 8200,
cluster traffic on 8201.

> **A real node boots SEALED and UNINITIALIZED — this is expected.** It does not
> serve secrets until you initialize it (`bao operator init`) and unseal it. See
> [Initialize & unseal](#initialize--unseal). For a one-command quick start, use
> [dev mode](#dev-mode-quick-start).

## Install

```bash
helm install bao oci://ghcr.io/quenchworks/charts/openbao
```

This installs the **default real raft server**. The pod becomes Ready while still
sealed (the readiness probe accepts sealed/uninit), so you can run the operator
steps against it.

## Initialize & unseal

Do this once per cluster (init), then unseal after each start (until you wire
auto-unseal). The `bao` CLI ships in the image.

```bash
# 1) Initialize ONCE. Prints the unseal key(s) + initial root token. SAVE THEM —
#    they cannot be recovered.
kubectl exec bao-openbao-0 -- sh -c \
  "BAO_ADDR=http://127.0.0.1:8200 bao operator init -key-shares=1 -key-threshold=1"

# 2) Unseal with the key from step 1 (repeat for each share if threshold > 1).
kubectl exec bao-openbao-0 -- sh -c \
  "BAO_ADDR=http://127.0.0.1:8200 bao operator unseal <UNSEAL_KEY>"

# 3) Use it with the root token.
kubectl exec bao-openbao-0 -- sh -c \
  "BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=<ROOT_TOKEN> bao kv put secret/hello v=quench"
kubectl exec bao-openbao-0 -- sh -c \
  "BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=<ROOT_TOKEN> bao kv get secret/hello"
```

For production, set up **shamir or auto-unseal (transit/KMS)** and **TLS** — both
are tracked follow-ups (see [Notes](#notes)).

## Dev mode (quick start)

For local testing only — an **auto-unsealed, in-memory** server with a fixed root
token. Data is **not** persisted; the token is well-known. **Never for production.**

```bash
helm install bao oci://ghcr.io/quenchworks/charts/openbao --set dev.enabled=true

# the root token is stored in a Secret (random if dev.rootToken is unset):
export BAO_TOKEN="$(kubectl get secret bao-openbao-dev -o jsonpath='{.data.dev-root-token}' | base64 -d)"
kubectl exec bao-openbao-0 -- sh -c \
  "BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=$BAO_TOKEN bao kv put secret/hello v=quench"
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/openbao \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/openbao` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node (HA raft cluster is a follow-up). |
| `dev.enabled` | `false` | `true` = auto-unsealed in-memory server (testing only). |
| `dev.rootToken` | `""` | Dev root token; random into a Secret if unset. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/openbao/data` (raft storage). |
| `service.apiPort` | `8200` | HTTP API / CLI. |
| `service.clusterPort` | `8201` | Raft cluster (headless service, future HA). |
| `networkPolicy.enabled` | `true` | Restricts API ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). Use `extraEnvVars` / `extraVolumes` to wire a
`seal` block, telemetry, or TLS materials for production.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Raft state lives on the writable `/openbao/data` PVC; the seeded `bao.hcl`
config and the CLI token-helper's `HOME` live on a writable emptyDir
(`/openbao/config`); `/tmp` is a writable emptyDir. `disable_mlock=true` because a
cap-dropped nonroot container cannot hold `CAP_IPC_LOCK`. **TLS is off by default**
(a follow-up) — the NetworkPolicy is the trust boundary; keep it enabled and front
the service with TLS termination if you expose it.

## Notes

Single node with raft integrated storage. A multi-node HA raft cluster (over the
headless service on 8201), TLS listeners, and auto-unseal (transit/KMS) are tracked
follow-ups. OpenBao is the MPL-2.0 fork of Vault — a clean-room, OSI-licensed
choice. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

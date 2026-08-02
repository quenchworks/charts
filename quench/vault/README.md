# Quenchworks Vault

> ### ⚠️ LICENSE — NOT OPEN SOURCE
> HashiCorp Vault 1.15.0 and later are licensed under the **Business Source License 1.1
> (BUSL-1.1)**, which is **not** OSI-approved open source: it restricts competing hosted
> use and only converts to MPL-2.0 after a change date. Do not treat Vault as open
> source.
>
> **Clean alternative:** [OpenBao](https://github.com/openbao/openbao) (MPL-2.0) is the
> truly-open, API- and CLI-compatible drop-in fork, shipped in this catalog as
> [`quench/openbao`](../openbao) / `oci://ghcr.io/quenchworks/charts/openbao`. **Prefer
> it for new deployments.** This chart exists for teams already committed to Vault.

Hardened [Vault](https://github.com/hashicorp/vault) secrets-management server on a
minimal, nonroot, 0-CVE image, built from source on Wolfi, cosign-signed and pinned by
digest. Single node with the `file` storage backend on a PVC; the HTTP API is on 8200,
cluster traffic on 8201.

> Note: a real node boots sealed and uninitialized, which is expected. It does not serve
> secrets until you initialize it (`vault operator init`) and unseal it. See
> [Initialize & unseal](#initialize--unseal). For a one-command quick start, use
> [dev mode](#dev-mode-quick-start).

> Note: there is **no web UI**. The image is built without Vault's `ui` build tag (the
> browser console needs a full Ember/pnpm asset build), so `ui = true` in the config does
> nothing. Use the CLI or the HTTP API.

## Install

```bash
helm install vault oci://ghcr.io/quenchworks/charts/vault
```

This installs the default real server. The pod becomes Ready while still sealed (the
readiness probe accepts sealed/uninit), so you can run the operator steps against it.

## Initialize & unseal

Do this once per cluster (init), then unseal after each start (until you wire
auto-unseal). The `vault` CLI ships in the image, and the image is **shell-free** — exec
the binary directly, no `sh -c`. `VAULT_ADDR` is already in the container's environment.

```bash
# 1) Initialize ONCE. Prints the unseal key(s) + initial root token. SAVE THEM;
#    they cannot be recovered.
kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1

# 2) Unseal with the key from step 1 (repeat for each share if threshold > 1).
kubectl exec vault-0 -- vault operator unseal <UNSEAL_KEY>
kubectl exec vault-0 -- vault status

# 3) Use it. `kubectl exec` cannot set env vars, so go through a port-forward
#    (or put VAULT_TOKEN in the pod env via extraEnvVars, from a Secret).
kubectl port-forward vault-0 8200:8200 &
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=<ROOT_TOKEN>
vault secrets enable -path=secret kv-v2
vault kv put secret/hello v=quench
vault kv get secret/hello
```

For production, configure auto-unseal (a `seal` block: transit/AWS KMS/GCP KMS/Azure Key
Vault) and a TLS listener — both are `server.config` edits, no chart change needed.

## Dev mode (quick start)

For local testing only: an auto-unsealed, in-memory server whose root token lives in a
Secret. Data is not persisted. Never use it for production.

```bash
helm install vault oci://ghcr.io/quenchworks/charts/vault --set dev.enabled=true

# VAULT_ADDR *and* VAULT_TOKEN are injected into the pod env, so exec needs nothing:
kubectl exec vault-0 -- vault kv put secret/hello v=quench
kubectl exec vault-0 -- vault kv get secret/hello

# the token itself, if you want it locally:
kubectl get secret vault-dev -o jsonpath='{.data.dev-root-token}' | base64 -d
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/vault \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/vault --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/vault` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node (HA is a follow-up). |
| `dev.enabled` | `false` | `true` = auto-unsealed in-memory server (testing only). |
| `dev.rootToken` | `""` | Dev root token; random into a Secret if unset. |
| `server.config` | `file` storage, TLS off, mlock off | The whole `vault.hcl`, rendered into a ConfigMap. Replace it to change storage, add `seal`, or enable TLS. |
| `persistence.enabled` | `true` | 8Gi PVC mounted at `/vault/data` (file storage). |
| `service.apiPort` | `8200` | HTTP API / CLI. |
| `service.clusterPort` | `8201` | Vault cluster port (headless service, future HA). |
| `networkPolicy.enabled` | `true` | Restricts API ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). Use `extraEnvVars` / `extraVolumes` to wire telemetry,
a token for exec-based automation, or TLS materials.

## Architecture

Vault runs as a **StatefulSet** so the node keeps a stable network identity and its own
persistent volume. The default is a real single node backed by the `file` storage backend
on a PVC mounted at `/vault/data`; with `persistence.enabled=false` that path is an
`emptyDir` and does not survive a restart. Each node advertises its API and cluster
addresses over a headless service (`<pod>.<headless>`, via `VAULT_API_ADDR` /
`VAULT_CLUSTER_ADDR`), which is the basis for a future multi-node HA topology.

Vault needs a config file to start, and the image is **shell-free** (no busybox), so
nothing inside it can synthesize one. The chart renders `server.config` into a ConfigMap
mounted at `/vault/config/vault.hcl` and overrides the container args to
`server -config=/vault/config/vault.hcl`. The image also carries a bootable default at
`/etc/vault/vault.hcl` so it runs standalone outside Kubernetes. Dev mode takes no config
file at all: the args become `server -dev …` and the ConfigMap is not rendered.

Two ports are exposed: HTTP (8200) for the API and CLI, and 8201 for Vault's cluster
traffic (idle with `file` storage, which is not an HA backend). A real node boots sealed
and uninitialized, and Vault's `/v1/sys/health` returns 503 (sealed) or 501
(uninitialized) in that state. Gating readiness on a plain 200 would leave the pod
NotReady forever, so the probes ask the health endpoint to return 200 for standby,
sealed, and uninitialized; the pod is reachable before you init and unseal it. Liveness is
a TCP check on the API port. In dev mode the node auto-unseals and the same endpoint
returns 200 anyway — which is what the CI install gate asserts, together with a real
kv-v2 put/get roundtrip.

The default topology is single-node (`replicaCount: 1`). A multi-node HA cluster (raft
integrated storage over the headless service) is a tracked follow-up; keep `replicaCount`
at 1 unless you also replace `server.config` with a raft/HA backend.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped.
Storage state lives on the writable `/vault/data` PVC; the config is a read-only
ConfigMap mount; `/tmp` is a writable emptyDir and doubles as `HOME` for the CLI's token
helper. `disable_mlock = true` because a cap-dropped nonroot container cannot hold
`CAP_IPC_LOCK` — the house pattern is to drop the capability, not to grant it, so run
Vault on swap-disabled nodes (the Kubernetes default) to keep the "master key never
reaches disk" guarantee. TLS is off by default; the NetworkPolicy is the trust boundary,
so keep it enabled and front the service with TLS termination if you expose it.

## Configuration examples

Size the data volume on a named storage class:

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-ssd
```

Auto-unseal against another Vault/OpenBao transit engine, and a TLS listener — all in
`server.config`:

```yaml
server:
  config: |
    disable_mlock = true
    ui            = false

    storage "file" {
      path = "/vault/data"
    }

    listener "tcp" {
      address       = "0.0.0.0:8200"
      tls_cert_file = "/vault/tls/tls.crt"
      tls_key_file  = "/vault/tls/tls.key"
    }

    seal "transit" {
      address    = "https://transit.example.internal:8200"
      key_name   = "unseal"
      mount_path = "transit/"
    }
extraVolumes:
  - name: tls
    secret:
      secretName: vault-tls
extraVolumeMounts:
  - name: tls
    mountPath: /vault/tls
    readOnly: true
extraEnvVars:
  - name: VAULT_TOKEN
    valueFrom:
      secretKeyRef:
        name: vault-transit-token
        key: token
```

## Uninstall

```bash
helm uninstall vault
```

PVCs provisioned by the `volumeClaimTemplate` are retained by Kubernetes on uninstall.
Delete them explicitly if you want the Vault data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=vault
```

## Notes

Single node with `file` storage. Multi-node HA, TLS listeners, and auto-unseal are
tracked follow-ups, all reachable through `server.config`. Vault is BUSL-1.1 and **not**
open source; OpenBao (MPL-2.0) is the clean fork — see the banner at the top. Depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

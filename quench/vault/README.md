# Quenchworks Vault

> ### ⚠️ LICENSE — NOT OPEN SOURCE
>
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
digest. Single node with the `file` storage backend on a PVC by default, or a
[multi-node raft cluster](#high-availability-raft) with `ha.enabled=true`. The HTTP API
is on 8200, cluster traffic on 8201. The **web UI is included** and served at `/ui/`.

> Note: a real node boots sealed and uninitialized, which is expected. It does not serve
> secrets until you initialize it (`vault operator init`) and unseal it. See
> [Initialize & unseal](#initialize--unseal). For a one-command quick start, use
> [dev mode](#dev-mode-quick-start).

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

| Key                           | Default                            | Notes                                                                                                      |
| ----------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/vault` |                                                                                                            |
| `image.digest`                | (CI-written)                       | Required. Charts pin by digest, never a tag.                                                               |
| `replicaCount`                | `1`                                | Single-node replica count. Ignored when `ha.enabled=true` (`ha.replicas` wins).                            |
| `ha.enabled`                  | `false`                            | `true` = multi-node raft cluster. Generates the HCL and ignores `server.config`.                            |
| `ha.replicas`                 | `3`                                | Raft node count. Keep it odd so a quorum survives losing one node.                                         |
| `ha.extraConfig`              | `""`                               | Extra HCL appended to the generated raft config (a `seal` stanza for auto-unseal, telemetry, ...).          |
| `autoscaling.enabled`         | `false`                            | HPA for the StatefulSet. Only valid with a shared external backend — see [Autoscaling](#autoscaling).       |
| `autoscaling.minReplicas`     | `1`                                | Lower bound. Enforced even when metrics are unavailable.                                                    |
| `autoscaling.maxReplicas`     | `3`                                | Upper bound.                                                                                                |
| `autoscaling.targetCPUUtilizationPercentage` | `80`                | CPU target. Set `targetMemoryUtilizationPercentage` to also scale on memory.                                 |
| `autoscaling.metrics`         | `[]`                               | Full `autoscaling/v2` metrics list (external/pods/object). Replaces the CPU + memory targets when set.       |
| `autoscaling.behavior`        | `{}`                               | `autoscaling/v2` scaling behavior (stabilization windows, policies).                                        |
| `dev.enabled`                 | `false`                            | `true` = auto-unsealed in-memory server (testing only).                                                    |
| `dev.rootToken`               | `""`                               | Dev root token; random into a Secret if unset.                                                             |
| `server.config`               | `file` storage, TLS off, mlock off | The whole `vault.hcl`, rendered into a ConfigMap. Replace it to change storage, add `seal`, or enable TLS. |
| `persistence.enabled`         | `true`                             | 8Gi PVC mounted at `/vault/data` (file storage).                                                           |
| `service.apiPort`             | `8200`                             | HTTP API / CLI.                                                                                            |
| `service.clusterPort`         | `8201`                             | Vault cluster port on the headless service. Carries raft traffic when `ha.enabled=true`.                   |
| `networkPolicy.enabled`       | `true`                             | Restricts API ingress to the release namespace.                                                            |
| `podDisruptionBudget.enabled` | `true`                             | `minAvailable: 1`.                                                                                         |
| `ingress.enabled`             | `false`                            | Create an Ingress for this chart. HTTP only.                                                               |
| `ingress.className`           | `""`                               | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                           |
| `ingress.annotations`         | `{}`                               | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                             |
| `ingress.servicePort`         | `null`                             | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.                         |
| `ingress.hosts`               | `[]`                               | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.                  |
| `ingress.tls`                 | `[]`                               | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.                       |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). Use `extraEnvVars` / `extraVolumes` to wire telemetry,
a token for exec-based automation, or TLS materials.

## Architecture

Vault runs as a **StatefulSet** so the node keeps a stable network identity and its own
persistent volume. The default is a real single node backed by the `file` storage backend
on a PVC mounted at `/vault/data`; with `persistence.enabled=false` that path is an
`emptyDir` and does not survive a restart. Each node advertises its API and cluster
addresses over a headless service (`<pod>.<headless>`, via `VAULT_API_ADDR` /
`VAULT_CLUSTER_ADDR`), which is what lets raft peers find each other under
[`ha.enabled`](#high-availability-raft).

Vault needs a config file to start, and the image is **shell-free** (no busybox), so
nothing inside it can synthesize one. The chart renders `server.config` into a ConfigMap
mounted at `/vault/config/vault.hcl` and overrides the container args to
`server -config=/vault/config/vault.hcl`. The image also carries a bootable default at
`/etc/vault/vault.hcl` so it runs standalone outside Kubernetes. Dev mode takes no config
file at all: the args become `server -dev …` and the ConfigMap is not rendered.

Two ports are exposed: HTTP (8200) for the API and CLI, and 8201 for Vault's cluster
traffic (idle with `file` storage, which is not an HA backend; carrying raft replication
once `ha.enabled=true`). A real node boots sealed
and uninitialized, and Vault's `/v1/sys/health` returns 503 (sealed) or 501
(uninitialized) in that state. Gating readiness on a plain 200 would leave the pod
NotReady forever, so the probes ask the health endpoint to return 200 for standby,
sealed, and uninitialized; the pod is reachable before you init and unseal it. Liveness is
a TCP check on the API port. In dev mode the node auto-unseals and the same endpoint
returns 200 anyway — which is what the CI install gate asserts, together with a real
kv-v2 put/get roundtrip.

## High availability (raft)

`ha.enabled=true` switches storage to Vault's **raft** integrated storage and runs
`ha.replicas` nodes (default 3, keep it odd so a quorum survives losing one node):

```bash
helm install vault oci://ghcr.io/quenchworks/charts/vault \
  --set ha.enabled=true --set ha.replicas=3
```

In this mode the chart **generates** the whole `vault.hcl` and ignores `server.config`,
because raft needs values only the chart knows: one `retry_join` block per replica, built
from the headless-service DNS names. Hand-maintaining those in values is how clusters end
up half-joined. Append your own HCL (a `seal` stanza for auto-unseal, telemetry) with
`ha.extraConfig`.

Every peer lists every peer, itself included: Vault ignores a `retry_join` pointing at
itself, so a uniform list means *any* pod can be the one you initialize. `node_id` is not
in the ConfigMap (a shared value would give every peer the same identity and raft would
refuse to form); it comes from `VAULT_RAFT_NODE_ID`, set to the pod name.

Bringing the cluster up, once:

```bash
# 1) Initialize ONE pod. Save the keys and token; they cannot be recovered.
kubectl exec vault-0 -- vault operator init -key-shares=5 -key-threshold=3

# 2) Unseal EVERY pod with the same keys. The joiners reach quorum via retry_join;
#    a joiner cannot unseal until its retry_join finds the leader, so retry if the
#    first attempt is refused.
for p in 0 1 2; do
  kubectl exec vault-$p -- vault operator unseal <key-1>
  kubectl exec vault-$p -- vault operator unseal <key-2>
  kubectl exec vault-$p -- vault operator unseal <key-3>
done

# 3) Confirm the cluster really formed: this must list ha.replicas VOTERS.
kubectl exec vault-0 -- vault operator raft list-peers
```

Step 3 is the check that matters. Three Running pods each reporting one voter are three
*separate* single-node clusters, which no pod-count or per-pod health check can tell
apart from a real cluster. The chart's release gate asserts the voter count for this
reason.

Two caveats worth knowing before you rely on it:

- **A sealed pod reports Ready.** The readiness probe asks Vault's health endpoint for
  `sealedcode=200&uninitcode=200`, so the StatefulSet rolls out and `helm install --wait`
  returns even though no node can serve a secret yet. That is deliberate — you need the
  pods reachable in order to run `operator init` / `unseal` against them — but it means
  **Ready does not mean usable here**. Check `vault status`, not the pod state. It also
  means a rolling image update restarts each pod into a sealed state and moves on without
  waiting for you; configure
  [auto-unseal](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal) via
  `ha.extraConfig` before you rely on unattended restarts.
- **Scaling down does not remove a raft peer.** Run
  `vault operator raft remove-peer <node_id>` *before* scaling in, or the cluster keeps
  counting a node that will never return and can lose quorum. The chart deliberately does
  not automate this: peer removal needs a privileged token, and getting it wrong destroys
  quorum.

## Autoscaling

Off by default, and for most installs it should stay off — Vault does not scale
horizontally the way a stateless service does. There is exactly one topology where an
HPA is meaningful: a **shared, external storage backend** (consul, dynamodb, gcs, …) set
through `server.config`, where every node reaches the same data and any node can serve.

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 80
server:
  config: |
    disable_mlock = true
    ui            = true
    storage "consul" { address = "consul:8500", path = "vault/" }
    listener "tcp"   { address = "0.0.0.0:8200", tls_disable = true }
```

The chart **refuses to render** the other two combinations, rather than letting you find
out in production:

| Combination | Why it is refused |
| --- | --- |
| `autoscaling` + `ha.enabled` (raft) | A raft cluster's voter count must be fixed. A scale-in does not run `vault operator raft remove-peer`, so raft keeps counting removed nodes as voters and the cluster **loses quorum**; a scale-out adds nodes that boot **sealed** and serve nothing; and the size ends up with two owners nothing reconciles — the HPA's bounds and `ha.replicas`, which the `retry_join` list is built from. |
| `autoscaling` + default `file` storage | `file` storage is per-pod, not shared. Replicas would be separate, separately sealed, separately initialized Vaults behind one Service, answering 501/503 at random, with a secret written to one node invisible on the others. |

Two things to know even in the supported case:

- **A new node boots sealed** and serves nothing until unsealed, so unless auto-unseal is
  configured (a `seal` stanza in `server.config`), adding replicas under load buys no
  capacity at all.
- **`replicaCount` is ignored** while autoscaling is on. The StatefulSet omits `replicas`
  so the HPA owns the count outright — otherwise every `helm upgrade` would reset the
  count and the HPA would scale back, fighting forever. Kubernetes starts it at 1 and the
  HPA raises it to `minReplicas` (it enforces the min bound even while metrics read
  `<unknown>`).

## Web UI

Vault's browser console is compiled into the image (built with `-tags ui`, the Ember
assets built from source) and enabled by default, served at `/ui/`:

```bash
kubectl port-forward svc/vault 8200:8200
# then open http://127.0.0.1:8200/ui/ and log in with a token
```

Set `ui = false` in `server.config` (or via `ha.extraConfig`) to close the route off. To
reach it from outside the cluster, enable the Ingress (`ingress.enabled=true`).

> A Vault built *without* the `ui` tag still answers `/ui/` with **HTTP 200** — serving a
> ~1.4 KB stub that reads "Vault UI is not available in this binary." So a 200 alone
> proves nothing. The real console is a ~1 MB `index.html` referencing hashed bundles
> under `/ui/assets/`, which is what this chart's gate and the image's smoke test assert.

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

Single node with `file` storage by default; multi-node raft HA via `ha.enabled`, and the
web UI is built in. TLS listeners and auto-unseal are not wired up as first-class values —
both are reachable through `server.config` / `ha.extraConfig`. Vault is BUSL-1.1 and **not**
open source; OpenBao (MPL-2.0) is the clean fork — see the banner at the top. Depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

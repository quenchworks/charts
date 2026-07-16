# QuenchWorks Cadence

Hardened [Cadence](https://cadenceworkflow.io/) — Uber's fault-tolerant, stateful
workflow orchestration engine — on a minimal, nonroot, 0-CVE image pinned by digest.
This chart runs the **all-in-one** server: one `cadence-server` process hosting all
four roles (frontend + history + matching + worker), backed by **Cassandra**.

All durable state lives in Cassandra, so the server runs on a read-only root
filesystem. This chart bundles the QuenchWorks Cassandra chart by default and can
also point at an external cluster.

Cadence uses **two keyspaces**: the main store and the visibility store. Six
shell-free init containers create both keyspaces and bring their schema to the latest
version with `cadence-cassandra-tool` before the server boots — the distroless image
ships no shell, so each step is a single tool invocation (create-Keyspace, then
`setup-schema`, then `update-schema`), and the first `create-Keyspace` doubles as the
wait-for-Cassandra gate.

## Install

```bash
# self-contained: bundles in-cluster Cassandra
helm install wf oci://ghcr.io/quenchworks/charts/cadence
```

## Connect

The frontend gRPC port `7833` is the main client/worker endpoint.

```bash
kubectl port-forward svc/wf-cadence 7833:7833
# point your SDK client at 127.0.0.1:7833
```

The bundled `cadence` CLI defaults to the **TChannel** transport — pass
`--transport grpc` when talking to the gRPC port. Register the domains your workers
use (no domain is auto-created):

```bash
kubectl exec -it deploy/wf-cadence -- \
  cadence --transport grpc --address 127.0.0.1:7833 --domain my-domain domain register --retention 1
```

## Cassandra

By default the chart bundles Cassandra with authentication disabled (a NetworkPolicy
is the trust boundary). The schema init containers create the two keyspaces
(`cadence` + `cadence_visibility`) and apply their schema.

Use an external cluster instead:

```yaml
cassandra:
  enabled: false
externalCassandra:
  host: cassandra.example.com
  port: 9042
  user: ""               # if the cluster requires auth
  password: "..."        # or existingSecret + existingSecretPasswordKey
keyspaces:
  main: cadence
  visibility: cadence_visibility
schemaSetup:
  replicationFactor: 3    # match the target ring
```

The external account must be able to create keyspaces and tables.

## Configuration

The server config is the `cadenceConfig` value (a Cassandra-backed config rendered
through `tpl`, replacing the sample the image does not ship). It is mounted read-only
at `/etc/cadence/config/config.yaml`; `dynamicConfig` is mounted alongside. Every
role binds on `${POD_IP}` — Cadence's own config loader expands that from the
downward-API `POD_IP` env at start, so ringpop advertises a routable address and the
Service/probe can reach the frontend (no shell/render step). Edit either value and
`helm upgrade` — the pod checksum annotation rolls the Deployment.

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Keep at 1 for the all-in-one server. |
| `services` | `frontend,history,matching,worker` | Roles the server process runs. |
| `numHistoryShards` | `4` | Fixed at first schema setup; cannot change later. |
| `cassandra.enabled` | `true` | Bundle the QuenchWorks Cassandra chart. |
| `cassandra.auth.enabled` | `false` | Bootstrap the default cassandra superuser. |
| `keyspaces.{main,visibility}` | `cadence` / `cadence_visibility` | Store keyspace names. |
| `externalCassandra.*` | — | Used when `cassandra.enabled=false`. |
| `schemaSetup.enabled` | `true` | Run the schema-bootstrap init containers. |
| `schemaSetup.replicationFactor` | `1` | RF used by create-Keyspace. |
| `service.{grpcPort,tchannelPort}` | `7833` / `7933` | Frontend Service ports. |
| `networkPolicy.allowExternal` | `false` | Allow frontend ingress from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | PDB (`minAvailable: 1`). |

Standard quench-common knobs (`resources`, `nodeSelector`, `affinity`, `tolerations`,
`podSecurityContext`, `containerSecurityContext`, probe overrides, `extraEnvVars`,
`extraVolumes`/`extraVolumeMounts`, `sidecars`, `initContainers`, …) are also
supported.

## Scaling

This release ships the all-in-one server only. `numHistoryShards` is fixed at first
schema setup and cannot change without a fresh keyspace. Scale-out — one Deployment
per role — is a future chart capability.

## Security

- Runs as nonroot (uid 1001), read-only root filesystem, all capabilities dropped.
- Image pinned by digest and cosign-signed (keyless):

```bash
cosign verify ghcr.io/quenchworks/images/cadence \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/cadence --owner quenchworks`.

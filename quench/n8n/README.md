# Quenchworks n8n

Hardened [n8n](https://n8n.io/) — a fair-code workflow automation platform with a
visual node editor and native AI/LLM agent nodes — on a minimal, nonroot, 0-CVE image
pinned by digest. n8n is a Node.js app; the whole flagged transitive npm CVE class is
cleared image-side with pinned `overrides`, and the app runs on a read-only root
filesystem as a single-replica StatefulSet. The editor UI, REST API and webhooks are
all served on port `5678`.

n8n keeps its encryption key, per-node config and binary data in `~/.n8n` on disk. By
default the workflow database is **SQLite** on that same volume; for production you point
it at an external **PostgreSQL**. An optional task-runner sidecar isolates Code-node
execution (JS/Python) into a separate process.

> n8n is distributed under the n8n Sustainable Use License (fair-code), not an OSI
> open-source license. Review [the license](https://github.com/n8n-io/n8n/blob/master/LICENSE.md)
> before commercial use; `.ee` (enterprise) features additionally require an n8n
> Enterprise License.

## Install

```bash
# self-contained: SQLite on a PVC, a generated encryption key
helm install flow oci://ghcr.io/quenchworks/charts/n8n \
  --set n8n.host=n8n.example.com
```

On first visit n8n prompts you to create the owner account. The encryption key that
protects stored credentials is generated once and kept in a Secret (see Notes).

## Connect

```bash
kubectl port-forward svc/flow-n8n 5678:5678
# open http://127.0.0.1:5678/
```

Health check:

```bash
curl -fsS http://127.0.0.1:5678/healthz
# -> {"status":"ok"}
```

## Verify the image

The image is pinned by digest and signed (cosign keyless). Verify the signature:

```bash
cosign verify ghcr.io/quenchworks/images/n8n \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Every build attaches an SPDX SBOM and SLSA provenance as attestations. Verify them
against the GitHub OIDC issuer (not `cosign download`):

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/n8n --owner quenchworks
```

## Architecture

- **Workload**: a single-replica `StatefulSet`. n8n holds instance state in `~/.n8n`,
  so a second replica would need queue mode (Postgres + Redis + worker pods), which is
  out of scope for this chart. `replicaCount` is fixed at 1.
- **Port**: `5678` (container port `http`), exposed by a `ClusterIP` Service. A headless
  Service backs the StatefulSet for stable pod DNS.
- **State / PVC**: `persistence.enabled=true` (default) provisions a PVC for
  `/home/node/.n8n` via a `volumeClaimTemplate` — the encryption key material, per-node
  config, binary data and (in SQLite mode) `database.sqlite`. `/home/node/.cache` and
  `/tmp` are ephemeral `emptyDir`s (regenerated each boot) so the read-only rootfs holds.
- **Database**: SQLite on the volume by default; set `database.type=postgresdb` to use an
  external PostgreSQL. This chart does not bundle a database subchart.
- **Probes**: liveness and readiness are HTTP `GET /healthz` on the `http` port, which
  returns 200 once n8n has run its migrations and is serving. Readiness is generous
  because first boot migrates the database.
- **Optional task runners**: `taskRunners.enabled=true` adds the `n8n-runners` sidecar.
  n8n hosts the task broker in-process and the sidecar connects over localhost with a
  shared, generated auth token to execute Code nodes out of the main process.
- **Hardening**: nonroot uid 1001, read-only root filesystem, all capabilities dropped
  (via `quench-common` defaults). A `NetworkPolicy` and `PodDisruptionBudget` are enabled
  by default.

## Database

### SQLite (default)

```yaml
database:
  type: sqlite
persistence:
  enabled: true
  size: 8Gi
```

The SQLite file lives at `~/.n8n/database.sqlite` on the PVC. Fine for a single instance
and light workloads; for anything production-shaped, use PostgreSQL.

### External PostgreSQL

```yaml
database:
  type: postgresdb
  postgresql:
    host: pg.example.com
    port: 5432
    database: n8n
    user: n8n
    password: ""          # inline, or use existingSecret + existingSecretPasswordKey
    schema: public
```

The password is stored in the managed Secret unless you supply
`database.postgresql.existingSecret`. `~/.n8n` is still kept on the PVC for the
encryption key and binary data.

## Task runners

```yaml
taskRunners:
  enabled: true
```

This attaches the `n8n-runners` sidecar (JavaScript + Python) and sets n8n to external
runner mode. The auth token shared between n8n and the runner is generated once and
persisted in the managed Secret. The Python runner is only available through this
sidecar — the base image ships no Python.

## Public URL

Set the externally reachable host so n8n builds correct editor, webhook and OAuth
callback URLs. Without it, generated URLs point at `localhost`:

```yaml
n8n:
  host: n8n.example.com
  protocol: https
  webhookUrl: https://n8n.example.com/   # only if a proxy rewrites the path
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/n8n` | Image repository. |
| `image.digest` | (pinned) | Image digest. CI-maintained; never a tag. |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `replicaCount` | `1` | Fixed at 1 (instance state on disk). |
| `n8n.host` | `localhost` | `N8N_HOST` — public hostname for generated URLs. |
| `n8n.protocol` | `http` | `N8N_PROTOCOL` (`http`/`https`). |
| `n8n.webhookUrl` | `""` | `WEBHOOK_URL` — override the derived webhook base URL. |
| `n8n.encryptionKey` | `""` | `N8N_ENCRYPTION_KEY`; generated + persisted if empty. |
| `n8n.existingSecret` | `""` | Use this Secret for the encryption key. |
| `n8n.existingSecretKey` | `encryption-key` | Key within `n8n.existingSecret`. |
| `database.type` | `sqlite` | `sqlite` or `postgresdb`. |
| `database.postgresql.host` | `""` | External PostgreSQL host (required for `postgresdb`). |
| `database.postgresql.port` | `5432` | External PostgreSQL port. |
| `database.postgresql.database` | `n8n` | Database name. |
| `database.postgresql.user` | `n8n` | Database user. |
| `database.postgresql.password` | `""` | Password (inline; or use `existingSecret`). |
| `database.postgresql.schema` | `public` | Schema. |
| `database.postgresql.existingSecret` | `""` | Secret holding the DB password. |
| `database.postgresql.existingSecretPasswordKey` | `password` | Key within that Secret. |
| `taskRunners.enabled` | `false` | Attach the `n8n-runners` sidecar (external mode). |
| `taskRunners.image.repository` | `ghcr.io/quenchworks/images/n8n-runners` | Runner image repository. |
| `taskRunners.image.digest` | (pinned) | Runner image digest. |
| `taskRunners.brokerPort` | `5679` | In-process task-broker port (localhost). |
| `taskRunners.authToken` | `""` | Shared auth token; generated + persisted if empty. |
| `taskRunners.resources` | requests 100m/128Mi, limits 1/512Mi | Sidecar resources. |
| `persistence.enabled` | `true` | Provision a PVC for `~/.n8n`. |
| `persistence.size` | `8Gi` | PVC size. |
| `persistence.storageClass` | (unset) | Storage class; default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning. |
| `resources` | requests 250m/256Mi, limits 2/1Gi | n8n container resources. |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `5678` | HTTP service + container port. |
| `serviceAccount.create` | `true` | Create a ServiceAccount. |
| `rbac.create` | `false` | Create an (empty) Role + RoleBinding. |
| `networkPolicy.enabled` | `true` | Create a NetworkPolicy. |
| `networkPolicy.allowExternal` | `true` | Allow HTTP ingress from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | Create a PodDisruptionBudget. |
| `podDisruptionBudget.minAvailable` | `1` | PDB minimum available. |

Standard `quench-common` knobs are also exposed: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`, `updateStrategy`,
`extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`, `lifecycleHooks`, `command`, `args`,
`podSecurityContext`, `containerSecurityContext`, and the `livenessProbe` /
`readinessProbe` / `custom*Probe` overrides.

## Uninstall

```bash
helm uninstall flow
```

The PVC and the managed Secret (which holds the encryption key) are not removed by
`helm uninstall`. Delete them explicitly only if you are sure you no longer need the
data:

```bash
kubectl delete pvc data-flow-n8n-0
kubectl delete secret flow-n8n
```

## Notes

- **Back up the encryption key.** `N8N_ENCRYPTION_KEY` protects every stored credential.
  It is generated once and preserved across upgrades. If you lose it (delete the Secret,
  or move to a fresh namespace) the stored credentials become undecryptable. Read it with:

  ```bash
  kubectl get secret flow-n8n -o jsonpath='{.data.encryption-key}' | base64 -d
  ```

- **Read-only rootfs writable paths** are `/home/node/.n8n` (the PVC), `/home/node/.cache`
  (n8n compiles static assets here on boot — ephemeral) and `/tmp`. If you install
  community nodes that need to write elsewhere, add an `extraVolumes` + `extraVolumeMounts`
  pair.
- **`persistence.enabled=false`** uses an `emptyDir` for `~/.n8n`. The CI gate runs this
  way; do not use it for real data — everything, including the encryption key and (in
  SQLite mode) the database, is lost when the pod restarts.
- The image build clears its transitive npm CVE class image-side with pinned `overrides`;
  the chart adds no runtime CVE handling.

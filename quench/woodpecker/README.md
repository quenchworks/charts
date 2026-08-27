# Quenchworks woodpecker

Hardened [Woodpecker CI](https://woodpecker-ci.org/) **server** on a minimal,
nonroot, 0-CVE image pinned by digest. It serves the web UI/API over HTTP on
port 8000 and accepts agent connections over gRPC on port 9000, running as
uid 1001 on a read-only root filesystem with all capabilities dropped. The
image is cosign-signed (keyless / Sigstore) and the chart pins it by the signed
digest, never a tag. State persists to a SQLite DB on a PVC, so the server runs
single-node.

> This chart ships the Woodpecker **server** only. Agents are deployed and
> scaled separately and authenticate with the shared `WOODPECKER_AGENT_SECRET`.

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

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/woodpecker \
  --owner quenchworks
```

## Values

| Key                                | Default                                 | Notes                                                                                     |
| ---------------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/woodpecker` |                                                                                           |
| `image.digest`                     | (CI-written)                            | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                 | `IfNotPresent`                          | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                     | `""`                                    | Override the chart name in resource names.                                                |
| `replicaCount`                     | `1`                                     | Stateful single node (SQLite); do not scale out (schema pins `maximum: 1`).               |
| `containerPort`                    | `8000`                                  | HTTP (web UI/API). Wired to `WOODPECKER_SERVER_ADDR`.                                     |
| `grpcPort`                         | `9000`                                  | gRPC for agents. Wired to `WOODPECKER_GRPC_ADDR`.                                         |
| `host`                             | `""`                                    | `WOODPECKER_HOST` — public server URL. **Required** in production.                        |
| `agentSecret.value`                | `""`                                    | Fixed `WOODPECKER_AGENT_SECRET`; creates a Secret. Rotate in prod.                        |
| `agentSecret.existingSecret`       | `""`                                    | Use an existing Secret instead.                                                           |
| `agentSecret.existingSecretKey`    | `WOODPECKER_AGENT_SECRET`               | Key within that Secret.                                                                   |
| `persistence.enabled`              | `true`                                  | 2Gi PVC mounted at `/var/lib/woodpecker` (SQLite DB).                                     |
| `persistence.size`                 | `2Gi`                                   | Requested volume size.                                                                    |
| `persistence.storageClass`         | `""`                                    | Default class if unset.                                                                   |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                     | PVC access modes.                                                                         |
| `persistence.annotations`          | `{}`                                    | Annotations on the PVC template.                                                          |
| `persistence.selector`             | `{}`                                    | Bind to a matching PV by selector.                                                        |
| `persistence.existingClaim`        | `""`                                    | Bind an existing PVC instead of provisioning one.                                         |
| `service.type`                     | `ClusterIP`                             | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.port`                     | `80`                                    | HTTP Service port -> container `http`.                                                    |
| `service.grpcPort`                 | `9000`                                  | gRPC Service port -> container `grpc`.                                                    |
| `resources.requests`               | `100m / 128Mi`                          | CPU / memory requests.                                                                    |
| `resources.limits`                 | `1 / 512Mi`                             | CPU / memory limits.                                                                      |
| `extraEnvVars`                     | `[]`                                    | Extra `WOODPECKER_*` env; put the forge config here.                                      |
| `extraEnvVarsSecret`               | `""`                                    | Secret of env vars (e.g. `WOODPECKER_GITHUB_SECRET`).                                     |
| `serviceAccount.create`            | `true`                                  | Token automount is off.                                                                   |
| `serviceAccount.name`              | `""`                                    | Use an existing ServiceAccount if set.                                                    |
| `serviceAccount.annotations`       | `{}`                                    | Annotations on the ServiceAccount.                                                        |
| `rbac.create`                      | `false`                                 | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`            | `true`                                  | Restricts HTTP + gRPC ingress to the release namespace.                                   |
| `networkPolicy.allowExternal`      | `false`                                 | Set `true` to allow ingress from any source.                                              |
| `podDisruptionBudget.enabled`      | `true`                                  |                                                                                           |
| `podDisruptionBudget.minAvailable` | `1`                                     |                                                                                           |
| `ingress.enabled`                  | `false`                                 | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`                | `""`                                    | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`              | `{}`                                    | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`              | `null`                                  | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`                    | `[]`                                    | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                      | `[]`                                    | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVarsCM`, `extraVolumes`, `extraVolumeMounts`,
`initContainers`, `sidecars`, `lifecycleHooks`, `command`, `args`,
`podSecurityContext`, `containerSecurityContext`, and the probe overrides
(`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Woodpecker runs as a **StatefulSet** so the node keeps a stable identity and its
own persistent volume. Two ports are exposed on the container: **HTTP (8000)**
for the web UI/API (`WOODPECKER_SERVER_ADDR`) and **gRPC (9000)** for agent
connections (`WOODPECKER_GRPC_ADDR`). The Service maps port 80 to the `http`
port and 9000 to the `grpc` port.

Because the root filesystem is read-only, two volumes are writable: the
`/var/lib/woodpecker` PVC that holds the SQLite database (falling back to an
`emptyDir` when `persistence.enabled=false`), and a `/tmp` emptyDir for scratch
space. Startup, liveness, and readiness probes all `httpGet /healthz`, which
returns 204 once the server is up.

The server stores its state in a local SQLite database, so the topology is
**single-node** — the schema pins `replicaCount` at 1 and it cannot be scaled
horizontally. Agents are a separate deployment: they connect over gRPC and
authenticate with the shared `WOODPECKER_AGENT_SECRET`.

## Configuration examples

A forge is mandatory — the server will not start without one. Configure it
through `extraEnvVars` (non-secret keys) plus a Secret referenced by
`extraEnvVarsSecret` (client secrets). See the
[Woodpecker forge docs](https://woodpecker-ci.org/docs/administration/forges/overview)
for the full `WOODPECKER_<FORGE>_*` variable set.

GitHub forge with a fixed agent secret and a larger DB volume:

```yaml
host: https://ci.example.com
agentSecret:
  value: "<32-byte-hex-secret>"
persistence:
  enabled: true
  size: 10Gi
extraEnvVars:
  - name: WOODPECKER_GITHUB
    value: "true"
  - name: WOODPECKER_GITHUB_CLIENT
    value: "<oauth-app-client-id>"
extraEnvVarsSecret: woodpecker-forge # holds WOODPECKER_GITHUB_SECRET
```

Point agents at an existing Secret rather than templating the value in:

```yaml
agentSecret:
  existingSecret: my-woodpecker-agent
  existingSecretKey: WOODPECKER_AGENT_SECRET
```

## Uninstall

```bash
helm uninstall my-woodpecker
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall — delete it explicitly if you want the SQLite data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-woodpecker
```

## Notes

Single node only: the server stores its state in a local SQLite database, so it
cannot be horizontally scaled. For HA you would need an external database
backend (`WOODPECKER_DATABASE_DRIVER` = `postgres` / `mysql`), tracked as a
follow-up. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Every container runs as
nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped, and the server is pinned by digest.
</content>
</invoke>

# Quenchworks Mailpit

Hardened [Mailpit](https://github.com/axllent/mailpit): an SMTP server that
captures everything your application sends and a web UI + REST API to read it
back. Runs as a single-replica Deployment listening on **SMTP 1025** and
**HTTP 8025**. Built from source on a minimal, nonroot, 0-CVE image that runs on
a read-only root filesystem with all capabilities dropped. The image is
cosign-signed (keyless / Sigstore) and the chart pins it by the signed digest,
never a tag.

## ⚠️ This is a development / test mail sink

Mailpit's SMTP listener **accepts mail from any client that can reach it** — no
authentication, no TLS, any recipient address — and never delivers any of it
onward. Every message lands in one inbox, and anyone who can open the web UI can
read all of them: password resets, invitations, magic links, anything your app
sends while pointed here.

That is the feature, not a bug, so the chart's job is to keep the blast radius
small:

- `networkPolicy.allowExternal` defaults to **`false`**, so only pods in the
  release namespace can submit mail or read the inbox. Use
  `networkPolicy.extraFrom` with a `namespaceSelector` when the senders live in
  another namespace — that is far better than opening it cluster-wide.
- `auth.username` / `auth.password` put HTTP basic auth on the web UI and REST
  API. Set them before enabling `ingress`. The SMTP port has no auth either way.
- Never expose either port to the public internet. An open relay-looking SMTP
  endpoint attracts abuse traffic even though Mailpit never relays.

## Install

```bash
helm install mail oci://ghcr.io/quenchworks/charts/mailpit
```

Point your application at the SMTP service:

```
host: mail-mailpit.<namespace>.svc.cluster.local
port: 1025          # no TLS, no auth
```

Read the mail:

```bash
kubectl port-forward svc/mail-mailpit 8025:8025
# UI:  http://127.0.0.1:8025/
curl http://127.0.0.1:8025/api/v1/messages
```

With basic auth configured, the UI prompts and the API takes `curl -u user:pass`.
`/livez` and `/readyz` stay unauthenticated so the kubelet probes keep working.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mailpit \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/mailpit \
  --owner quenchworks
```

## Values

| Key                                | Default                              | Notes                                                                                     |
| ---------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/mailpit` |                                                                                           |
| `image.digest`                     | (CI-written)                         | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                 | `IfNotPresent`                       | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                     | `""`                                 | Override the chart name in resource names.                                                |
| `replicaCount`                     | `1`                                  | One inbox, one SQLite database, one pod. Keep it at 1.                                    |
| `smtp.port`                        | `1025`                               | Container port for the SMTP listener.                                                     |
| `smtp.maxMessages`                 | `500`                                | Messages retained; oldest pruned. `0` = unlimited.                                        |
| `ui.port`                          | `8025`                               | Container port for the web UI and REST API.                                               |
| `ui.webroot`                       | `""`                                 | Serve the UI/API under a sub-path, e.g. `/mailpit/`.                                      |
| `auth.username`                    | `""`                                 | Basic auth for the UI/API (`MP_UI_AUTH`). Empty means **no auth**.                        |
| `auth.password`                    | `""`                                 | Required when `auth.username` is set; stored in a chart-managed Secret.                   |
| `auth.existingSecret`              | `""`                                 | Take the credential from a Secret you manage instead.                                     |
| `auth.existingSecretKey`           | `ui-auth`                            | Key holding a `user:password` string.                                                     |
| `persistence.enabled`              | `false`                              | PVC for the message database. When `false`, an `emptyDir` (inbox empty on each restart).  |
| `persistence.path`                 | `/data`                              | Directory holding `mailpit.db`; also the mount point.                                     |
| `persistence.size`                 | `1Gi`                                | Requested volume size when enabled.                                                       |
| `persistence.storageClass`         | `""`                                 | Default class if unset.                                                                   |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                  | PVC access modes.                                                                         |
| `persistence.annotations`          | `{}`                                 | Annotations on the PVC.                                                                   |
| `persistence.existingClaim`        | `""`                                 | Bind an externally-managed PVC instead of provisioning one.                               |
| `extraArgs`                        | `[]`                                 | Extra flags appended to the `mailpit` command, e.g. `--max-age=24h`.                      |
| `resources.requests`               | `cpu 50m / mem 64Mi`                 | CPU / memory requests.                                                                    |
| `resources.limits`                 | `cpu 500m / mem 256Mi`               | CPU / memory limits.                                                                      |
| `service.type`                     | `ClusterIP`                          | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.ports.smtp`               | `1025`                               | SMTP submission port.                                                                     |
| `service.ports.http`               | `8025`                               | Web UI and REST API.                                                                      |
| `serviceAccount.create`            | `true`                               | Token automount is off.                                                                   |
| `serviceAccount.name`              | `""`                                 | Use an existing ServiceAccount if set.                                                    |
| `serviceAccount.annotations`       | `{}`                                 | Annotations on the ServiceAccount.                                                        |
| `rbac.create`                      | `false`                              | Minimal Role/RoleBinding.                                                                 |
| `networkPolicy.enabled`            | `true`                               | Restricts ingress to both listeners.                                                      |
| `networkPolicy.allowExternal`      | `false`                              | Namespace-only by default. Add `networkPolicy.extraFrom` for other namespaces.            |
| `podDisruptionBudget.enabled`      | `false`                              | Off: a `minAvailable: 1` PDB on a single-replica test tool blocks node drains.            |
| `ingress.enabled`                  | `false`                              | Ingress for the web UI. Set `auth.*` first. HTTP only.                                    |
| `ingress.className`                | `""`                                 | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`              | `{}`                                 | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`              | `null`                               | Backend port. Unset resolves `service.ports.http`.                                        |
| `ingress.hosts`                    | `[]`                                 | e.g. `[{host: mail.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                      | `[]`                                 | Standard Ingress TLS list, e.g. `[{hosts: [mail.example.com], secretName: mail-tls}]`.    |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

Mailpit runs as a **Deployment** behind a **ClusterIP** Service exposing two
ports: `smtp` (1025) and `http` (8025). The entrypoint is the `mailpit` binary;
the chart passes `--listen=0.0.0.0:<ui.port>` and `--smtp=0.0.0.0:<smtp.port>`
explicitly because the binary's defaults bind `[::]`, which fails on IPv4-only
nodes. It also passes `--disable-version-check` so a cluster workload never
phones home, `--database` (see below), `--max`, and any `extraArgs`.

Basic-auth credentials reach the container as `MP_UI_AUTH` from a Secret, never
a ConfigMap or a flag, so they do not appear in `kubectl describe pod`.

Because the root filesystem is read-only, the SQLite message store is always a
mounted volume at `persistence.path` — an `emptyDir` by default (a test mailbox
is throwaway data and a fresh inbox per pod is usually what you want), or a
PersistentVolumeClaim with `persistence.enabled=true`.

Liveness and readiness hit `/livez` and `/readyz`, which Mailpit serves without
authentication.

There is **no HorizontalPodAutoscaler in this chart, deliberately**: the inbox is
one SQLite database owned by one pod, so a second replica would silently split
captured mail across pods and half your assertions would fail at random. The
PodDisruptionBudget is off for the same reason — a `minAvailable: 1` budget on a
single-replica Deployment blocks node drains for a tool nobody needs to be
highly available.

## Configuration examples

Senders in another namespace, inbox kept across restarts, UI behind auth:

```yaml
auth:
  username: qa
  password: <strong-password>
persistence:
  enabled: true
  size: 5Gi
networkPolicy:
  extraFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: staging
```

Aggressive pruning for a busy CI namespace:

```yaml
smtp:
  maxMessages: 100
extraArgs:
  - --max-age=6h
```

## Uninstall

```bash
helm uninstall mail
```

A PVC provisioned with `persistence.enabled=true` is retained by Kubernetes on
uninstall — delete it explicitly if you want the captured mail gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=mail
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. Mailpit is MIT licensed.

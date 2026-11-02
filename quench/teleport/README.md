# Quenchworks teleport

Hardened [Teleport](https://goteleport.com/) (AGPL community build), the identity-based access
plane for SSH, Kubernetes, databases, applications and Windows desktops, on a nonroot, 0-CVE
image built from source, pinned by digest and cosign-signed (keyless / Sigstore). The chart runs
one auth + proxy process with the embedded web UI; its SQLite backend, host CAs and session
recordings live on a PVC, and `teleport.yaml` ships in a ConfigMap mounted at
`/etc/teleport/teleport.yaml`.

## Install

```bash
helm install my-teleport oci://ghcr.io/quenchworks/charts/teleport \
  --set clusterName=teleport.example.com \
  --set publicAddr=teleport.example.com:443
```

Create the first user and open the invite link it prints:

```bash
kubectl exec -it my-teleport-teleport-0 -- \
  tctl users add admin --roles=editor,access --logins=root
```

> `clusterName` cannot change after the first start (it is part of the cluster CA).
> `publicAddr` must be the host:port users and agents really reach, normally an Ingress or
> LoadBalancer with a trusted certificate; invite links and agent joins use it.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/teleport \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/teleport --owner quenchworks`.

## Values

| Key                                | Default                                | Notes                                                                                     |
| ---------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/teleport`  |                                                                                           |
| `image.digest`                     | (CI-written)                           | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                 | `IfNotPresent`                         | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                     | `""`                                   | Override the chart name in resource names.                                                |
| `replicaCount`                     | `1`                                    | Fixed at 1: the SQLite backend has one writer.                                            |
| `clusterName`                      | `teleport.local`                       | Teleport cluster name; immutable after the first start.                                   |
| `publicAddr`                       | `""`                                   | host:port users and agents reach the proxy on; empty uses the Service name.               |
| `ports.web`                        | `3080`                                 | HTTPS web UI, API and `tsh login` (TLS always on).                                        |
| `ports.tunnel`                     | `3024`                                 | Reverse tunnels from agents and leaf clusters.                                            |
| `ports.auth`                       | `3025`                                 | Auth service, on the headless Service only.                                               |
| `ports.diag`                       | `3000`                                 | `/healthz`, `/readyz` and `/metrics`; backs the probes.                                   |
| `config`                           | (see values.yaml)                      | Full `teleport.yaml`, `tpl`-rendered into a ConfigMap.                                    |
| `resources.requests`               | `cpu 100m / mem 256Mi`                 |                                                                                           |
| `resources.limits`                 | `cpu 1 / mem 1Gi`                      |                                                                                           |
| `args`                             | `["start", "--config=/etc/teleport/teleport.yaml"]` | Override only for maintenance commands.                                      |
| `service.type`                     | `ClusterIP`                            | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.port`                     | `3080`                                 | Forwards to the web listener (TLS); `tunnel` and `diag` are published too.                |
| `tls.enabled`                      | `false`                                | Serve this certificate on the web listener (`https_keypairs`); mounted at `/tls`.         |
| `tls.existingSecret`               | `""`                                   | Use this `kubernetes.io/tls` Secret (1st choice).                                         |
| `tls.certManager.enabled`          | `false`                                | Request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice).       |
| `tls.selfSigned.validityDays`      | `365`                                  | Otherwise Helm generates a CA + certificate, kept across upgrades.                        |
| `persistence.enabled`              | `true`                                 | 2Gi PVC mounted at `/var/lib/teleport`.                                                   |
| `persistence.size`                 | `2Gi`                                  | Requested volume size; session recordings grow it.                                        |
| `persistence.dataDir`              | `/var/lib/teleport`                    | Teleport's `data_dir`.                                                                    |
| `persistence.storageClass`         | `""`                                   | Default class if unset.                                                                   |
| `persistence.accessModes`          | `["ReadWriteOnce"]`                    | PVC access modes.                                                                         |
| `persistence.existingClaim`        | `""`                                   | Bind an existing PVC instead of provisioning one.                                         |
| `serviceAccount.create`            | `true`                                 | Token automount is off.                                                                   |
| `serviceAccount.name`              | `""`                                   | Use an existing ServiceAccount if set.                                                    |
| `rbac.create`                      | `false`                                | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`            | `true`                                 | Ingress to `web` and `tunnel` from the release namespace.                                 |
| `networkPolicy.allowExternal`      | `false`                                | Set `true` to allow ingress from any source.                                              |
| `podDisruptionBudget.enabled`      | `true`                                 |                                                                                           |
| `podDisruptionBudget.minAvailable` | `1`                                    |                                                                                           |
| `ingress.enabled`                  | `false`                                | Create an Ingress to `service.port`. The backend is HTTPS: set the controller's backend protocol. |
| `ingress.className`                | `""`                                   | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`              | `{}`                                   | Controller annotations (backend protocol, cert-manager issuer, ...).                      |
| `ingress.servicePort`              | `null`                                 | Backend port. Unset resolves `service.port`.                                              |
| `ingress.hosts`                    | `[]`                                   | e.g. `[{host: teleport.example.com}]`.                                                    |
| `ingress.tls`                      | `[]`                                   | Standard Ingress TLS list.                                                                |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `podSecurityContext`, `containerSecurityContext`, and
the probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

One pod runs Teleport's auth and proxy services; the SSH node service is off (servers join as
agents). Teleport keeps cluster state in a SQLite backend under `data_dir` on the PVC, so the
chart runs a single replica; an HA deployment needs an external backend and a different
topology. `teleport.yaml` lives in `.Values.config`, rendered through Helm's `tpl` and mounted
read-only. The proxy's web listener is always TLS (Teleport's own self-signed certificate unless
`tls.*` supplies one). The diagnostics listener on `ports.diag` serves `/healthz` (liveness) and
`/readyz` (readiness) plus Prometheus `/metrics`. The pod runs nonroot (uid 1001) on a read-only
root filesystem with all capabilities dropped; editing `config` and running `helm upgrade` rolls
the pod via a checksum annotation.

## Configuration examples

Publish the proxy on a LoadBalancer for agents outside the cluster:

```yaml
service:
  type: LoadBalancer
publicAddr: teleport.example.com:3080
networkPolicy:
  allowExternal: true
```

Use a certificate from cert-manager on the web listener:

```yaml
tls:
  enabled: true
  certManager:
    enabled: true
    issuerRef: { name: letsencrypt, kind: ClusterIssuer }
    dnsNames: [teleport.example.com]
```

## Uninstall

```bash
helm uninstall my-teleport
```

The PVC from the `volumeClaimTemplate` is retained on uninstall. Delete it to drop the cluster
state, CAs and recordings:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-teleport
```

## Notes

The image is the AGPL community source built from scratch (no Teleport trademark community
build type). The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

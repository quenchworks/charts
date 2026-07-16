# Quenchworks headscale

Hardened [headscale](https://headscale.net/), an open-source implementation of the
Tailscale control server, on a minimal, nonroot, 0-CVE image pinned by digest and
cosign-signed (keyless / Sigstore). Single node; it persists its SQLite DB and
generated noise/machine keys to a PVC, and its config ships via a ConfigMap mounted
at `/etc/headscale/config.yaml`. The chart pins the image by its signed digest,
never a tag.

## Install

```bash
helm install my-headscale oci://ghcr.io/quenchworks/charts/headscale \
  --set serverUrl=https://headscale.example.com
```

Then create a user and a pre-auth key, and point a client at the server:

```bash
kubectl exec -it my-headscale-headscale-0 -- \
  headscale --config /etc/headscale/config.yaml users create alice
kubectl exec -it my-headscale-headscale-0 -- \
  headscale --config /etc/headscale/config.yaml preauthkeys create --user 1

tailscale up --login-server https://headscale.example.com
```

> `serverUrl` must be a URL your nodes can reach (normally an HTTPS endpoint via an
> Ingress/LoadBalancer terminating TLS in front of this Service) and must not be a
> subdomain of `dns.base_domain`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/headscale \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/headscale --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/headscale` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Fixed at 1: single SQLite writer, do not scale out. |
| `containerPort` | `8080` | HTTP API / coordination port (nonroot). |
| `metricsPort` | `9090` | Prometheus metrics port, exposed on the Service as `metrics`. |
| `serverUrl` | `http://127.0.0.1:8080` | The login-server URL clients use. Override this. |
| `config` | (see values.yaml) | Full headscale `config.yaml`, `tpl`-rendered into a ConfigMap. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `args` | `["serve"]` | Entrypoint verb; override only for maintenance verbs. |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | Forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC mounted at `/var/lib/headscale` (DB + noise key + socket). |
| `persistence.size` | `1Gi` | Requested volume size. |
| `persistence.dataDir` | `/var/lib/headscale` | Mount point; must match the paths in `config`. |
| `persistence.storageClass` | `""` | Default class if unset. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount if set. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the release namespace. |
| `networkPolicy.allowExternal` | `false` | Set `true` to allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.minAvailable` | `1` | |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `command`, `podSecurityContext`, `containerSecurityContext`, and
the probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

headscale runs as a single-node StatefulSet. It is the single writer of a local
SQLite database plus its generated noise/machine keys, so it cannot be scaled
horizontally (the schema caps `replicaCount` at 1). The entire `config.yaml` lives
in `.Values.config` and is rendered through Helm's `tpl`, so `serverUrl`, the ports
and the data dir resolve at render time; it is mounted read-only at
`/etc/headscale/config.yaml`. All state paths (noise key, SQLite DB, control socket)
point at the PVC data dir (`/var/lib/headscale`) so headscale can write them under
the read-only root filesystem, generating its noise private key there on first boot.

The HTTP API and coordination endpoint is on `containerPort` (8080); Prometheus
metrics on `metricsPort` (9090), exposed on the Service as `metrics`; gRPC (remote
CLI) stays on loopback (`127.0.0.1:50443`) unless you deliberately expose it.
`/health` (HTTP 200) backs both the liveness and readiness probes. The pod runs
nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped;
only the PVC is writable. Editing `config` and running `helm upgrade` rolls the pod
via a checksum annotation.

## Configuration examples

Open the control server to clients outside the cluster (default restricts ingress
to the release namespace):

```yaml
networkPolicy:
  allowExternal: true
```

Larger data volume on a named storage class:

```yaml
persistence:
  size: 5Gi
  storageClass: fast-ssd
```

Change any headscale setting by editing `config`. It is rendered whole, so copy the
default block from `values.yaml` and edit the keys you need, e.g. MagicDNS base
domain and upstream resolvers:

```yaml
config: |
  server_url: {{ .Values.serverUrl }}
  listen_addr: 0.0.0.0:{{ .Values.containerPort }}
  # ... keep the rest of the default config ...
  dns:
    magic_dns: true
    base_domain: corp.example.com
    nameservers:
      global:
        - 9.9.9.9
```

## Uninstall

```bash
helm uninstall my-headscale
```

The PVC provisioned by the `volumeClaimTemplate` is retained by Kubernetes on
uninstall. Delete it explicitly to drop the SQLite DB and generated keys:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-headscale
```

## Notes

Single node only: headscale is the single writer of a local SQLite database plus
generated keys, so it cannot be horizontally scaled with this chart. For HA you
would run an external PostgreSQL backend and a different topology, tracked as a
follow-up. The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by
digest.

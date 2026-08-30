# Quenchworks ChartMuseum

Hardened [ChartMuseum](https://github.com/helm/chartmuseum), an HTTP server that
turns a storage backend into a Helm chart repository, running as a Deployment
that serves the repository (and the optional write API) on port 8080. Built from
source on a minimal, nonroot, 0-CVE image that runs on a read-only root
filesystem with all capabilities dropped. The image is cosign-signed (keyless /
Sigstore) and the chart pins it by the signed digest, never a tag.

## ⚠️ The default install accepts anonymous writes

`api.enabled` defaults to `true` (ChartMuseum's own default) and `auth.username`
defaults to empty. That combination means **every `/api` route is unauthenticated**:
anyone who can reach the Service can publish a chart —

```bash
curl --data-binary @evil-1.0.0.tgz http://<service>:8080/api/charts
```

— and, unless `api.disableDelete=true`, delete existing ones. That is convenient
for a throwaway namespace and wrong for anything else. Pick one before you expose
this outside a trusted network:

```bash
# 1. read/write with HTTP basic auth (anonymous pulls still allowed)
helm install museum oci://ghcr.io/quenchworks/charts/chartmuseum \
  --set auth.username=publisher --set auth.password='<strong-password>' \
  --set auth.anonymousGet=true

# 2. read-only repository, no write API at all
helm install museum oci://ghcr.io/quenchworks/charts/chartmuseum \
  --set api.enabled=false
```

`networkPolicy.allowExternal` is `true` by default (a chart repo is normally
pulled from everywhere); set it to `false` to confine clients to the release
namespace. The chart also warns about this in its post-install NOTES.

## Install

```bash
helm install museum oci://ghcr.io/quenchworks/charts/chartmuseum
```

That gives you local-disk storage on an 8Gi PersistentVolumeClaim. Use it as a
repository over a port-forward:

```bash
kubectl port-forward svc/museum-chartmuseum 8080:8080
curl http://127.0.0.1:8080/health                      # {"healthy":true}
helm repo add museum http://127.0.0.1:8080
curl --data-binary @mychart-0.1.0.tgz http://127.0.0.1:8080/api/charts
curl http://127.0.0.1:8080/api/charts
```

With basic auth configured, `helm repo add` takes `--username/--password` and
uploads take `curl -u user:pass`.

## Storage backends

`storage.backend` is passed straight to ChartMuseum's `--storage` and accepts
`local`, `amazon`, `google`, `microsoft`, `oracle`, `alibaba`, `openstack`,
`baidu`, `tencent`, and `etcd`.

Only `local` is wired end-to-end by this chart, because it is the only backend
that needs a Kubernetes volume: the chart provisions it (`persistence`) and
mounts it at `storage.local.path`. Every other backend is credentials plus a
bucket, which ChartMuseum reads from flags and environment variables — so they go
through `extraArgs` and `extraEnvVars` rather than a bespoke value per cloud:

```yaml
storage:
  backend: amazon
persistence:
  enabled: false          # no local disk needed; the mount becomes an emptyDir
extraArgs:
  - --storage-amazon-bucket=my-charts
  - --storage-amazon-region=eu-west-1
  - --storage-amazon-prefix=prod
extraEnvVarsSecret: chartmuseum-aws   # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
```

The full flag list (`--storage-google-bucket`, `--storage-microsoft-container`,
`--storage-oracle-bucket`, …) is `chartmuseum --help` in the same image:

```bash
docker run --rm ghcr.io/quenchworks/images/chartmuseum:0.16.6 --help
```

With any shared object store you may raise `replicaCount` or enable
`autoscaling`; with `local` you must not (see Architecture).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/chartmuseum \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/chartmuseum \
  --owner quenchworks
```

## Values

| Key                                          | Default                                  | Notes                                                                                     |
| -------------------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`                           | `ghcr.io/quenchworks/images/chartmuseum` |                                                                                           |
| `image.digest`                               | (CI-written)                             | Required. Charts pin by digest, never a tag.                                              |
| `image.pullPolicy`                           | `IfNotPresent`                           | `Always`, `IfNotPresent`, or `Never`.                                                     |
| `nameOverride`                               | `""`                                     | Override the chart name in resource names.                                                |
| `replicaCount`                               | `1`                                      | Keep at 1 with the `local` backend (ReadWriteOnce, per-pod).                              |
| `api.enabled`                                | `true`                                   | All `/api` routes, including upload and delete. **Anonymous unless `auth` is set.**       |
| `api.allowOverwrite`                         | `false`                                  | Re-upload an existing chart version without `?force`.                                     |
| `api.disableDelete`                          | `false`                                  | Keep uploads but drop the DELETE route.                                                   |
| `auth.username`                              | `""`                                     | HTTP basic auth user. Empty means **no auth at all**.                                     |
| `auth.password`                              | `""`                                     | Required when `auth.username` is set; stored in a chart-managed Secret.                   |
| `auth.existingSecret`                        | `""`                                     | Take the credentials from a Secret you manage instead.                                    |
| `auth.existingSecretUserKey`                 | `basic-auth-user`                        | Key in `auth.existingSecret` holding the username.                                        |
| `auth.existingSecretPasswordKey`             | `basic-auth-pass`                        | Key in `auth.existingSecret` holding the password.                                        |
| `auth.anonymousGet`                          | `false`                                  | With auth on, still allow unauthenticated pulls and `index.yaml`.                         |
| `storage.backend`                            | `local`                                  | `local`, `amazon`, `google`, `microsoft`, `oracle`, `alibaba`, `openstack`, `baidu`, `tencent`, `etcd`. |
| `storage.local.path`                         | `/storage`                               | Mount point and `--storage-local-rootdir`.                                                |
| `persistence.enabled`                        | `true`                                   | PVC for chart storage. When `false`, the mount is an `emptyDir` (charts lost on restart). |
| `persistence.size`                           | `8Gi`                                    | Requested volume size.                                                                    |
| `persistence.storageClass`                   | `""`                                     | Default class if unset.                                                                   |
| `persistence.accessModes`                    | `["ReadWriteOnce"]`                      | PVC access modes.                                                                         |
| `persistence.annotations`                    | `{}`                                     | Annotations on the PVC.                                                                   |
| `persistence.existingClaim`                  | `""`                                     | Bind an externally-managed PVC instead of provisioning one.                               |
| `contextPath`                                | `""`                                     | Serve under a base path, e.g. `/charts` (`--context-path`).                               |
| `chartUrl`                                   | `""`                                     | Absolute URL for the `.tgz` links in `index.yaml`. Set it behind an Ingress or proxy.     |
| `extraArgs`                                  | `[]`                                     | Extra flags appended to the `chartmuseum` command (backend bucket/region flags live here).|
| `resources.requests`                         | `cpu 50m / mem 64Mi`                     | CPU / memory requests.                                                                    |
| `resources.limits`                           | `cpu 500m / mem 512Mi`                   | CPU / memory limits.                                                                      |
| `service.type`                               | `ClusterIP`                              | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                               |
| `service.port`                               | `8080`                                   | Repository and API.                                                                       |
| `autoscaling.enabled`                        | `false`                                  | HPA on CPU (autoscaling/v2). Only safe with a shared object-storage backend.              |
| `autoscaling.minReplicas`                    | `1`                                      |                                                                                           |
| `autoscaling.maxReplicas`                    | `5`                                      |                                                                                           |
| `autoscaling.targetCPUUtilizationPercentage` | `80`                                     |                                                                                           |
| `serviceAccount.create`                      | `true`                                   | Token automount is off.                                                                   |
| `serviceAccount.name`                        | `""`                                     | Use an existing ServiceAccount if set.                                                    |
| `serviceAccount.annotations`                 | `{}`                                     | Annotations on the ServiceAccount.                                                        |
| `rbac.create`                                | `false`                                  | Minimal Role/RoleBinding.                                                                 |
| `networkPolicy.enabled`                      | `true`                                   | Restricts ingress.                                                                        |
| `networkPolicy.allowExternal`                | `true`                                   | Set `false` to restrict ingress to the release namespace.                                 |
| `podDisruptionBudget.enabled`                | `true`                                   |                                                                                           |
| `podDisruptionBudget.minAvailable`           | `1`                                      |                                                                                           |
| `ingress.enabled`                            | `false`                                  | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`                          | `""`                                     | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`                        | `{}`                                     | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`                        | `null`                                   | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`                              | `[]`                                     | e.g. `[{host: charts.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                                | `[]`                                     | Standard Ingress TLS list, e.g. `[{hosts: [charts.example.com], secretName: charts-tls}]`. |

Plus the shared `quench-common` knobs: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `schedulerName`, `terminationGracePeriodSeconds`,
`updateStrategy`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
`extraVolumes`, `extraVolumeMounts`, `initContainers`, `sidecars`,
`lifecycleHooks`, `podSecurityContext`, `containerSecurityContext`, and the
probe overrides (`livenessProbe`, `readinessProbe`,
`customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`).

## Architecture

ChartMuseum runs as a **Deployment** behind a **ClusterIP** Service on container
port `8080`. The entrypoint is the `chartmuseum` binary; the chart builds its
flags from values (`--port`, `--listen-host=0.0.0.0`, `--storage`,
`--storage-local-rootdir`, `--disable-api`, `--allow-overwrite`,
`--disable-delete`, `--auth-anonymous-get`, `--context-path`, `--chart-url`) and
appends `extraArgs`. Basic-auth credentials are injected as `BASIC_AUTH_USER` /
`BASIC_AUTH_PASS` from a Secret — never from a ConfigMap or a command-line flag,
so they do not show up in `kubectl describe pod`.

`--listen-host=0.0.0.0` is set deliberately: the binary defaults to `[::]`, which
fails to bind on IPv4-only nodes.

Because the root filesystem is read-only, chart storage is always a mounted
volume at `storage.local.path` — a PersistentVolumeClaim when
`persistence.enabled=true` (the default), otherwise an `emptyDir`. That mount
exists regardless of `storage.backend`; with a cloud backend it is simply unused,
and you can set `persistence.enabled=false` to make it ephemeral.

Both probes hit `/health`, which ChartMuseum serves unauthenticated as soon as it
is listening. The default topology is **single replica**: the `local` backend is
one pod's ReadWriteOnce disk, so scaling out — by `replicaCount` or `autoscaling`
— corrupts nothing but silently splits the repository across pods. Switch to a
shared object-storage backend first.

## Configuration examples

Read-only mirror behind an Ingress, charts published out of band:

```yaml
api:
  enabled: false
chartUrl: https://charts.example.com
ingress:
  enabled: true
  hosts:
    - host: charts.example.com
  tls:
    - hosts: [charts.example.com]
      secretName: charts-tls
```

Authenticated publishing with credentials you manage:

```yaml
auth:
  existingSecret: chartmuseum-credentials   # keys: basic-auth-user, basic-auth-pass
  anonymousGet: true
api:
  allowOverwrite: false
  disableDelete: true
networkPolicy:
  allowExternal: false
```

## Uninstall

```bash
helm uninstall museum
```

The PVC provisioned with `persistence.enabled=true` is retained by Kubernetes on
uninstall — delete it explicitly if you want the charts gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=museum
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. ChartMuseum is Apache-2.0 licensed.

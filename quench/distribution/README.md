# Quenchworks Distribution

Hardened [Distribution](https://github.com/distribution/distribution), the CNCF
reference OCI/Docker registry server for storing and distributing container
images and other OCI artifacts, on a minimal, nonroot, 0-CVE image built from
source on Wolfi, cosign-signed and pinned by digest. Runs as a single-replica
StatefulSet with a persistent blob store at `/var/lib/registry` and the registry
HTTP API on port 5000.

## Install

```bash
helm install registry oci://ghcr.io/quenchworks/charts/distribution
```

Check it from a client pod:

```bash
kubectl run reg-check --rm -it --restart=Never --image=ghcr.io/quenchworks/images/busybox -- \
  wget -qS -O- http://registry-distribution:5000/v2/
```

Grow the blob store and pick a storage class:

```bash
helm install registry oci://ghcr.io/quenchworks/charts/distribution \
  --set persistence.size=50Gi \
  --set persistence.storageClass=fast-ssd
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/distribution \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/distribution --owner quenchworks`.

## Values

| Key                           | Default                                   | Notes                                                                                         |
| ----------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/distribution` |                                                                                               |
| `image.digest`                | (CI-written)                              | Required. Charts pin by digest, never a tag.                                                  |
| `image.pullPolicy`            | `IfNotPresent`                            |                                                                                               |
| `nameOverride`                | `""`                                      | Override the chart name in resource names.                                                    |
| `replicaCount`                | `1`                                       | Filesystem storage is single-writer; scale-out needs shared storage.                          |
| `config.configYml`            | filesystem on the PVC, API on :5000       | The full registry `config.yml`, mounted from a ConfigMap over `/etc/distribution/config.yml`. |
| `config.existingConfigMap`    | `""`                                      | Use your own ConfigMap (key `config.yml`) instead; wins over `configYml`.                     |
| `persistence.enabled`         | `true`                                    | Blob store volume at `/var/lib/registry`.                                                     |
| `persistence.size`            | `10Gi`                                    | PVC size.                                                                                     |
| `persistence.storageClass`    | `""`                                      | Default class if unset.                                                                       |
| `persistence.accessModes`     | `["ReadWriteOnce"]`                       |                                                                                               |
| `persistence.existingClaim`   | `""`                                      | Use an existing PVC instead of a volumeClaimTemplate.                                         |
| `persistence.annotations`     | `{}`                                      | PVC annotations.                                                                              |
| `persistence.selector`        | `{}`                                      | PVC selector.                                                                                 |
| `resources.requests`          | `cpu 100m / mem 128Mi`                    |                                                                                               |
| `resources.limits`            | `cpu 1 / mem 512Mi`                       |                                                                                               |
| `service.type`                | `ClusterIP`                               | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                   |
| `service.port`                | `5000`                                    | Registry HTTP API.                                                                            |
| `serviceAccount.create`       | `true`                                    | Token automount is off.                                                                       |
| `serviceAccount.name`         | `""`                                      | Use an existing ServiceAccount.                                                               |
| `rbac.create`                 | `false`                                   | Minimal Role/RoleBinding.                                                                     |
| `networkPolicy.enabled`       | `true`                                    | Restricts ingress.                                                                            |
| `networkPolicy.allowExternal` | `true`                                    | Set `false` to restrict ingress to the release namespace.                                     |
| `podDisruptionBudget.enabled` | `true`                                    | `minAvailable: 1`.                                                                            |
| `ingress.enabled`             | `false`                                   | Create an Ingress for this chart. HTTP only.                                                  |
| `ingress.className`           | `""`                                      | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.              |
| `ingress.annotations`         | `{}`                                      | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                |
| `ingress.servicePort`         | `null`                                    | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.            |
| `ingress.hosts`               | `[]`                                      | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.     |
| `ingress.tls`                 | `[]`                                      | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.          |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A single registry runs as a StatefulSet so its blob store keeps a stable identity
and a persistent volume. The default `config.configYml` uses the **filesystem**
storage backend rooted at `/var/lib/registry` (the PVC), an in-memory blob
descriptor cache, and serves the registry API on `:5000` with the storagedriver
health check enabled. Liveness and readiness both `httpGet /v2/` (the registry
API base returns 200 once ready). The container runs nonroot on a read-only root
filesystem: the blob store PVC and a `/tmp` emptyDir are the only writable paths,
and the config is mounted read-only. When `persistence.enabled=false` the data
volume falls back to an emptyDir (ephemeral — for the CI install gate).

## Configuration examples

Switch to S3 blob storage and keep the health check:

```yaml
config:
  configYml: |
    version: 0.1
    log:
      level: info
    storage:
      s3:
        region: us-east-1
        bucket: my-registry
        rootdirectory: /
      cache:
        blobdescriptor: inmemory
    http:
      addr: :5000
    health:
      storagedriver:
        enabled: true
        interval: 10s
        threshold: 3
```

Bring your own config ConfigMap (managed outside the chart, key `config.yml`):

```yaml
config:
  existingConfigMap: my-registry-config
```

## Uninstall

```bash
helm uninstall registry
```

StatefulSet PVCs are not deleted with the release. Remove the blob store
explicitly if you no longer need it:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=registry
```

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest. Filesystem storage is single-writer, so keep `replicaCount: 1`
unless you switch `config.configYml` to a shared backend (S3/GCS). Distribution
serves the registry API without authentication by default — enable auth/TLS in
`config.configYml` and keep the NetworkPolicy as the trust boundary before
exposing it beyond the cluster.

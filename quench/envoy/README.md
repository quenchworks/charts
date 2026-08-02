# Quenchworks Envoy

Hardened [Envoy](https://github.com/envoyproxy/envoy), the CNCF L7 edge and
service proxy, on a minimal, nonroot, 0-CVE image pinned by digest. It runs as a
stateless Deployment on a read-only root filesystem with all capabilities
dropped. The image is cosign-signed (keyless / Sigstore) and the chart pins it by
the signed digest, never a tag.

## Install

```bash
helm install proxy oci://ghcr.io/quenchworks/charts/envoy
```

The container runs `envoy -c /etc/envoy/envoy.yaml --service-cluster <release>`
nonroot. With no config supplied it serves a default bootstrap: an admin endpoint
on `0.0.0.0:9901` and one example listener on `:10000` that returns a 200
`direct_response`. The Service exposes both. Check readiness over a port-forward:

```bash
kubectl port-forward svc/proxy-envoy 9901:9901 10000:10000
curl http://127.0.0.1:9901/ready   # 200 LIVE
curl http://127.0.0.1:10000/       # 200
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/envoy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/envoy --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/envoy` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `config` | `""` | Inline bootstrap YAML, mounted at `/etc/envoy/envoy.yaml` and passed via `-c`. Empty uses the chart's default bootstrap. |
| `existingConfigMap` | `""` | Use your own ConfigMap (key `envoy.yaml`) instead; wins over `config`. |
| `serviceCluster` | release name | `--service-cluster` value. |
| `extraArgs` | `[]` | Extra flags appended to the `envoy` command. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `10000` | Proxy listener the default bootstrap serves. |
| `service.adminPort` | `9901` | Admin endpoint (health, stats, config dump). |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs Envoy driven entirely by its bootstrap config. Set
`config` to the full bootstrap YAML (a string) and it renders to a ConfigMap,
mounts at `/etc/envoy/envoy.yaml`, and is passed via `-c`; `existingConfigMap`
points at an externally-managed ConfigMap (key `envoy.yaml`) and wins over
`config`. `extraArgs` are appended to the command. The default bootstrap serves
the admin endpoint on `9901` (which backs the `/ready` probes) and one example
listener on `10000`. The root filesystem is read-only: Envoy's admin socket and
logs live on an emptyDir mounted at `/tmp`, which is the only writable path.
There is no persistence, and the workload scales horizontally with `autoscaling`
or `replicaCount`.

## Configuration examples

Replace the default bootstrap with your own listener and cluster:

```yaml
config: |
  admin:
    address:
      socket_address: { address: 0.0.0.0, port_value: 9901 }
  static_resources:
    listeners:
      - name: listener_0
        address:
          socket_address: { address: 0.0.0.0, port_value: 10000 }
        filter_chains:
          - filters:
              - name: envoy.filters.network.http_connection_manager
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                  stat_prefix: ingress_http
                  http_filters:
                    - name: envoy.filters.http.router
                      typed_config:
                        "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
                  route_config:
                    virtual_hosts:
                      - name: backend
                        domains: ["*"]
                        routes:
                          - match: { prefix: "/" }
                            route: { cluster: upstream }
    clusters:
      - name: upstream
        connect_timeout: 1s
        type: STRICT_DNS
        load_assignment:
          cluster_name: upstream
          endpoints:
            - lb_endpoints:
                - endpoint:
                    address:
                      socket_address: { address: my-backend, port_value: 8080 }
```

Bring your own bootstrap ConfigMap (managed outside the chart, key `envoy.yaml`):

```yaml
existingConfigMap: my-envoy-bootstrap
```

## Uninstall

```bash
helm uninstall proxy
```

Nothing persists: the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

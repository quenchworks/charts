# Quenchworks Apache APISIX

Hardened [Apache APISIX](https://github.com/apache/apisix), the cloud-native API
gateway built on OpenResty/LuaJIT, on a minimal, nonroot, 0-CVE image built from
source, cosign-signed and pinned by digest. Runs as a stateless Deployment with
its configuration in etcd: routes, upstreams, plugins and certificates are
written through the REST Admin API at runtime, not through this chart's values.

The bundled control-plane store is the catalogue's own hardened
[quench/etcd](../etcd) chart, so there is one etcd implementation in the
catalogue rather than a second vendored copy.

## Install

```bash
helm install gw oci://ghcr.io/quenchworks/charts/apisix
```

That gives you APISIX plus a 3-node etcd. The Admin API key is generated at
install time and kept in a Secret:

```bash
KEY=$(kubectl get secret gw-apisix-admin -o jsonpath='{.data.admin-key}' | base64 -d)
kubectl port-forward svc/gw-apisix 9180:9180 9080:9080

# declare a route
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H "X-API-KEY: $KEY" \
  -d '{"uri":"/get","upstream":{"type":"roundrobin","nodes":{"httpbin.org:80":1}}}'

# and call it through the proxy
curl http://127.0.0.1:9080/get
```

The key is only generated when `admin.key` is empty, and every later
`helm upgrade` reads it back out of the Secret rather than rotating it. Set
`admin.key` yourself, or point `admin.existingSecret` at a Secret you manage.

### Ports

| Port | What |
|------|------|
| 9080 | HTTP proxy — the data plane |
| 9443 | HTTPS proxy, only when `tls.enabled=true` (certificates come from the Admin API, not from values) |
| 9180 | Admin API, key-protected |
| 9090 | Control API, bound to `0.0.0.0` so the kubelet's probes can reach `/v1/healthcheck` |
| 9091 | Prometheus, at `/apisix/prometheus/metrics` |

All five are APISIX's own defaults and all sit above 1024, so the nonroot user
binds them with no capability granted.

### An existing etcd

```bash
helm install gw oci://ghcr.io/quenchworks/charts/apisix \
  --set etcd.enabled=false \
  --set 'etcdClient.hosts={http://etcd.data.svc.cluster.local:2379}'
```

Leaving both off is an error, not a silent half-install: APISIX has nowhere to
keep its configuration without etcd.

### Anything the values do not model

`config.extra` is deep-merged over everything the chart renders into
`conf/config.yaml`, so plugin lists, service discovery, etcd TLS and nginx
tuning are all reachable without a fork:

```yaml
config:
  extra:
    apisix:
      enable_ipv6: false
    plugins:
      - jwt-auth
      - limit-req
      - prometheus
```

## Ingress controller

The APISIX Ingress Controller is a **separate chart**,
[`apisix-ingress-controller`](../apisix-ingress-controller). It was an optional
component of this chart in 0.0.1 and never worked: the controller cannot sync
without its `adc` sidecar, which this chart did not run, and it owns twelve
cluster-scoped `apisix.apache.org` CRDs plus an IngressClass — objects a data-plane
chart must not claim if you ever want two APISIX releases in one cluster.

Install it alongside and point it at this release's Admin API:

```bash
helm install aic oci://ghcr.io/quenchworks/charts/apisix-ingress-controller \
  --set dataPlane.endpoints[0]=http://<release>-apisix:9180 \
  --set dataPlane.adminKey.existingSecret=<release>-apisix-admin
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/apisix \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/apisix --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/apisix` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `etcd.enabled` | `true` | Bundle the quench/etcd chart as the control-plane store. Any other key under `etcd` is passed straight to it. |
| `etcdClient.hosts` | `[]` | Client URLs of an existing etcd. Required when `etcd.enabled=false`. |
| `etcdClient.prefix` | `/apisix` | Key prefix APISIX owns. |
| `etcdClient.timeout` | `30` | Seconds APISIX waits on an etcd call. |
| `admin.enabled` | `true` | Serve the Admin API. `false` makes this release a data plane only. |
| `admin.allowAdmin` | `["0.0.0.0/0"]` | CIDRs allowed to call the Admin API. |
| `admin.key` | `""` | The `X-API-KEY` value. Empty generates a random 32-character key, stable across upgrades. |
| `admin.existingSecret` | `""` | Read the key from a Secret you manage instead. |
| `admin.existingSecretKey` | `admin-key` | Key inside that Secret. |
| `tls.enabled` | `false` | Open the HTTPS proxy listener. Certificates are loaded through the Admin API. |
| `metrics.enabled` | `true` | Bind the Prometheus exporter to `0.0.0.0`. |
| `metrics.serviceMonitor.enabled` | `false` | Prometheus Operator ServiceMonitor. |
| `metrics.serviceMonitor.interval` | `30s` | |
| `containerPorts.http` / `.https` / `.admin` / `.control` / `.metrics` | `9080` / `9443` / `9180` / `9090` / `9091` | APISIX's own defaults. |
| `config.extra` | `{}` | YAML deep-merged over the rendered `conf/config.yaml`. |
| `resources.requests` | `cpu 100m / mem 256Mi` | |
| `resources.limits` | `cpu 1 / mem 1Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `9080` | HTTP proxy. Also what the Ingress fronts. |
| `service.httpsPort` / `.adminPort` / `.metricsPort` | `9443` / `9180` / `9091` | Only published when the matching feature is on. |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off; APISIX itself never calls the API server. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the gateway's own ports. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `ingress.enabled` | `false` | Create an Ingress in front of the proxy port. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations. |
| `ingress.hosts` | `[]` | e.g. `[{host: api.example.com, paths: [{path: /, pathType: Prefix}]}]`. |
| `ingress.tls` | `[]` | Standard Ingress TLS list. |

Plus the shared quench-common knobs: `podLabels`, `podAnnotations`,
`commonLabels`, `commonAnnotations`, `nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `priorityClassName`, `schedulerName`,
`terminationGracePeriodSeconds`, `updateStrategy`, `extraEnvVars`,
`extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`, `extraVolumeMounts`,
`initContainers`, `sidecars`, `lifecycleHooks`, `command`, `args`,
`podSecurityContext`, `containerSecurityContext`, and the probe overrides
(`livenessProbe`, `readinessProbe`, `customLivenessProbe`,
`customReadinessProbe`, `customStartupProbe`).

## How it runs

The container is nonroot (uid 1001) on a read-only root filesystem. APISIX needs
exactly three writable paths, each an `emptyDir`:

* `/usr/local/apisix/conf` — `apisix init` regenerates `nginx.conf` here on every
  start. The image ships it empty and re-seeds it from a read-only
  `conf.default/`, so the chart's `config.yaml` is mounted on top and everything
  else (`mime.types`, cert templates) is filled in behind it.
* `/usr/local/apisix/logs` — error log and the `worker_events` sockets.
* `/tmp` — nginx's five temp paths, redirected there by `config.yaml`.

An init container waits for etcd on a TCP connect before the gateway starts:
`apisix init_etcd` exits when the store is not up yet, and Helm creates
Deployments before StatefulSets, so without it a fresh install would
CrashLoopBackOff its way through etcd's own startup.

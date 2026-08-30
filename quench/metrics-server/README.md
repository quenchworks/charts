# Quenchworks Metrics Server

Hardened [Metrics Server](https://github.com/kubernetes-sigs/metrics-server), the
cluster-wide aggregator of container resource metrics that backs `kubectl top`
and the Horizontal Pod Autoscaler, on a minimal, nonroot, 0-CVE image built from
source, cosign-signed and pinned by digest.

## Read this before installing

Metrics Server scrapes every kubelet over HTTPS and, by default, **verifies the
kubelet's serving certificate**. That only works on a cluster whose kubelets were
issued cluster-signed serving certificates (`serverTLSBootstrap: true` plus
something approving the CSRs). Plenty of clusters — kind, default kubeadm, k3s,
minikube, some managed distributions — leave the kubelet on a self-signed
certificate.

On those clusters a default install of this chart **will not become Ready**. The
pod logs `x509: certificate signed by unknown authority` and `kubectl top` reports
that metrics are not available. That is the correct, honest failure, and this
chart does not paper over it.

Your options, best first:

1. Fix the kubelets: enable `serverTLSBootstrap` and approve the CSRs.
2. Point `kubelet.certificateAuthority` at the CA that did sign them.
3. `--set kubelet.insecureTLS=true` — the scrape stays encrypted and is still
   authenticated by Metrics Server's own bearer token, but the kubelet's identity
   is no longer checked. Anything able to intercept that connection can
   impersonate a kubelet and feed you fabricated metrics, which your HPA will
   then scale on. Do it knowingly.

## Install

```bash
helm install metrics oci://ghcr.io/quenchworks/charts/metrics-server
```

On a cluster with self-signed kubelet certificates (kind, minikube, k3s):

```bash
helm install metrics oci://ghcr.io/quenchworks/charts/metrics-server \
  --set kubelet.insecureTLS=true
```

## Verify it is actually working

`Ready` is not the bar, and neither is the APIService reporting `Available`.
The bar is real numbers:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io    # AVAILABLE must be True
kubectl top nodes                                 # must print CPU/memory values
kubectl top pods -A
```

`Available: True` while `kubectl top` says "metrics not available" means the API
is registered but no scrape has landed — read `kubectl logs deployment/metrics-metrics-server`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/metrics-server \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/metrics-server --owner quenchworks`.

## Values

| Key                                           | Default                                     | Notes                                                                                                                     |
| --------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `image.repository`                            | `ghcr.io/quenchworks/images/metrics-server` |                                                                                                                           |
| `image.digest`                                | (CI-written)                                | Required. Charts pin by digest, never a tag.                                                                              |
| `image.pullPolicy`                            | `IfNotPresent`                              |                                                                                                                           |
| `nameOverride`                                | `""`                                        | Override the chart name in resource names.                                                                                |
| `replicaCount`                                | `1`                                         | >1 requires `--enable-aggregator-routing` on the kube-apiserver.                                                          |
| `securePort`                                  | `4443`                                      | Not 443: the container is nonroot with no capabilities and cannot bind a privileged port.                                 |
| `metricResolution`                            | `15s`                                       | Scrape interval. Must be >= 10s.                                                                                          |
| `kubelet.insecureTLS`                         | **`false`**                                 | **Security tradeoff.** `true` stops verifying kubelet serving certificates. Required on kind/minikube/k3s. Read above.     |
| `kubelet.certificateAuthority`                | `""`                                        | In-container path to a CA bundle for kubelet certificates (mount it via `extraVolumes`). The safe alternative to the above. |
| `kubelet.preferredAddressTypes`               | `[InternalIP, ExternalIP, Hostname]`        | The binary's own default leads with `Hostname`, which fails where node names do not resolve.                              |
| `kubelet.useNodeStatusPort`                   | `true`                                      | Dial the port advertised in the node status instead of assuming 10250.                                                    |
| `kubelet.requestTimeout`                      | `10s`                                       |                                                                                                                           |
| `apiService.create`                           | `true`                                      | Registers `v1beta1.metrics.k8s.io`. Cluster-wide singleton — see below.                                                    |
| `apiService.insecureSkipTLSVerify`            | `true`                                      | The server self-signs its serving certificate, so the kube-apiserver cannot verify it. Set `false` only with real certs.   |
| `apiService.caBundle`                         | `""`                                        | base64 PEM. Required when `insecureSkipTLSVerify: false`.                                                                 |
| `extraArgs`                                   | `[]`                                        | Extra flags, e.g. `--tls-cert-file` / `--tls-private-key-file`.                                                           |
| `resources.requests`                          | `cpu 100m / mem 200Mi`                      | Memory scales with cluster size (~4Mi per node, ~1Mi per pod is a working rule of thumb).                                 |
| `resources.limits`                            | `cpu 500m / mem 500Mi`                      |                                                                                                                           |
| `service.type`                                | `ClusterIP`                                 |                                                                                                                           |
| `service.port`                                | `443`                                       | What the APIService dials; mapped to `securePort`.                                                                        |
| `serviceAccount.create`                       | `true`                                      |                                                                                                                           |
| `serviceAccount.automountServiceAccountToken` | `true`                                      | Required: it is an API-server client and delegates auth back to it.                                                       |
| `rbac.create`                                 | `true`                                      | Three grants — see `templates/rbac.yaml`. Dropping any one breaks it differently.                                         |
| `rbac.aggregatedMetricsReader`                | `true`                                      | Extends the built-in view/edit/admin roles so non-admins can run `kubectl top`.                                            |
| `networkPolicy.enabled`                       | `true`                                      |                                                                                                                           |
| `networkPolicy.allowExternal`                 | `true`                                      | Must stay `true`: the kube-apiserver dials this Service from the control-plane host, outside the pod network.              |
| `podDisruptionBudget.enabled`                 | `false`                                     | A PDB over a single replica blocks node drains rather than protecting availability.                                       |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A Deployment runs `/usr/bin/metrics-server` serving HTTPS on container port
`4443`; the Service maps `443` to it, and an `APIService` registers
`v1beta1.metrics.k8s.io` so the kube-apiserver proxies metrics requests there.
Every `metricResolution` the server scrapes each node's kubelet resource-metrics
endpoint and keeps only the most recent sample in memory — it is a live view, not
a time-series database, and it stores nothing.

With no certificate supplied, the apiserver library generates a self-signed
serving certificate at startup and writes it to `--cert-dir`. The root filesystem
is read-only, so the chart mounts an `emptyDir` at `/tmp` and points `--cert-dir`
there; the matching `apiService.insecureSkipTLSVerify: true` is what lets the
kube-apiserver accept it.

Probes are `/livez` and `/readyz` over HTTPS on the secure port. `/readyz` only
goes green after a scrape has succeeded, so a kubelet TLS failure surfaces as an
unready pod instead of an empty metrics API.

RBAC is three separate grants, and each fails differently if dropped: a
ClusterRole for the scrape and the objects it attributes samples to
(`nodes/metrics`, `nodes/stats`, `nodes`, `pods`, `namespaces`); a binding to the
built-in `system:auth-delegator` so incoming aggregated-API requests can be
authenticated and authorized against the kube-apiserver (without it every
`kubectl top` is a 403 from a perfectly healthy pod); and a RoleBinding in
`kube-system` to the built-in `extension-apiserver-authentication-reader` so the
front-proxy client CA can be read (without it the process does not start). That
RoleBinding is the only object this chart creates outside its own namespace.

The container runs nonroot on a read-only root filesystem with all capabilities
dropped.

## One per cluster

`v1beta1.metrics.k8s.io` is a cluster-scoped singleton. A second release
installed with `apiService.create: true` will take the object over and repoint
the whole cluster's metrics API at itself. Managed control planes (GKE, EKS with
the add-on, AKS) usually register it already — install with
`--set apiService.create=false`, or do not install this at all.

## Uninstall

```bash
helm uninstall metrics
```

The APIService goes with it, and `kubectl top` stops working cluster-wide until
something else registers `v1beta1.metrics.k8s.io`. Nothing persists — Metrics
Server holds only the last scrape, in memory.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Metrics Server is not a
monitoring system: it keeps one sample per pod and node for autoscaling to read.
Use Prometheus (and `prometheus-adapter` for custom HPA metrics) for history.

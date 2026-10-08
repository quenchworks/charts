# ztunnel

[ztunnel](https://github.com/istio/ztunnel) is Istio's per-node proxy for ambient mode. Every pod
in the mesh gets a SPIFFE identity, and ztunnel carries its TCP traffic to the destination node's
ztunnel over HBONE (HTTP CONNECT inside mutual TLS), with no sidecar in the pod. This chart runs it
on the QuenchWorks ztunnel image (built from the istio/ztunnel source, 0 fixable CVEs,
cosign-signed, pinned by digest).

## Install

Ambient needs three charts at the same Istio version, all in `istio-system`: istiod with ambient
on, istio-cni, and this chart.

```sh
helm install istiod oci://ghcr.io/quenchworks/charts/istiod -n istio-system --create-namespace \
  --set fullnameOverride=istiod \
  --set 'extraEnvVars[0].name=PILOT_ENABLE_AMBIENT' --set-string 'extraEnvVars[0].value=true' \
  --set 'extraEnvVars[1].name=CA_TRUSTED_NODE_ACCOUNTS' --set 'extraEnvVars[1].value=istio-system/ztunnel'
helm install istio-cni oci://ghcr.io/quenchworks/charts/istio-cni -n istio-system
helm install ztunnel oci://ghcr.io/quenchworks/charts/ztunnel -n istio-system
kubectl label namespace <ns> istio.io/dataplane-mode=ambient
kubectl -n istio-system logs ds/ztunnel | grep 'connection complete'
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `caAddress` / `xdsAddress` | `istiod.istio-system.svc:15012` | istiod's CA and xDS server |
| `clusterId` | `Kubernetes` | must match istiod's `CLUSTER_ID` |
| `logLevel` | `info` | `RUST_LOG`; access logs are at info |
| `extraEnvVars` | `[]` | other ztunnel settings |
| `resources` | 200m / 512Mi, 1Gi limit | per node |

## Privileges

Like upstream, ztunnel runs as root with NET_ADMIN, SYS_ADMIN and NET_RAW and a read-only root
filesystem: it opens listeners inside each ambient pod's network namespace, which istio-cni hands
it over a socket in `/var/run/ztunnel`. It mounts no Kubernetes API token; it authenticates to
istiod with a projected token for the `istio-ca` audience. The ServiceAccount is named `ztunnel`,
which istiod must trust (`CA_TRUSTED_NODE_ACCOUNTS=istio-system/ztunnel`).

Not included: waypoint proxies (L7), which need the Envoy proxy image.

## Release gate

The gate installs istiod (ambient), istio-cni and this chart from this repository into kind, puts
a client and a server in an ambient namespace, and passes only when the request succeeds AND
ztunnel logs that connection with SPIFFE identities on both ends over HBONE (mutual TLS).

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

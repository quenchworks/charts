# Istio CNI (ambient)

The Istio CNI node agent for [ambient mode](https://istio.io/latest/docs/ambient/): a DaemonSet
that chains the `istio-cni` plugin into each node's existing CNI configuration and, for every pod
in the mesh, programs its network namespace to send traffic through the node's ztunnel. It runs on
the QuenchWorks istio-cni image (built from the istio/istio source on Wolfi, 0 fixable CVEs,
cosign-signed, pinned by digest).

## Install

Ambient needs three charts at the same Istio version, all in `istio-system`: istiod with ambient
on, this chart, and ztunnel.

```sh
helm install istiod oci://ghcr.io/quenchworks/charts/istiod -n istio-system --create-namespace \
  --set fullnameOverride=istiod \
  --set 'extraEnvVars[0].name=PILOT_ENABLE_AMBIENT' --set-string 'extraEnvVars[0].value=true' \
  --set 'extraEnvVars[1].name=CA_TRUSTED_NODE_ACCOUNTS' --set 'extraEnvVars[1].value=istio-system/ztunnel'
helm install istio-cni oci://ghcr.io/quenchworks/charts/istio-cni -n istio-system
helm install ztunnel oci://ghcr.io/quenchworks/charts/ztunnel -n istio-system
kubectl label namespace <ns> istio.io/dataplane-mode=ambient
```

The node's own CNI (kindnet, Calico, Cilium without kube-proxy replacement, ...) keeps doing pod
networking; this plugin is chained after it (`CHAINED_CNI_PLUGIN`).

## Values

| Key | Default | Meaning |
|---|---|---|
| `excludeNamespaces` | `kube-system` | pods the agent never touches |
| `ambient.dnsCapture` | `true` | ztunnel answers the pods' DNS (ServiceEntry names) |
| `ambient.ipv6` | `true` | also redirect IPv6 |
| `cniBinDir` / `cniConfDir` | `/opt/cni/bin` / `/etc/cni/net.d` | the node's CNI paths |
| `extraConfig` | `{}` | other agent settings (upstream's `istio-cni-config` keys) |

## Privileges

Like upstream, the agent runs as root with NET_ADMIN, NET_RAW, SYS_ADMIN, SYS_PTRACE and
DAC_OVERRIDE: it writes the plugin and its configuration onto the host and enters pod network
namespaces. Object names are fixed (`istio-cni-node`, `istio-cni-config`, `istio-cni`), so install
once per cluster. Sidecar mode and the istio-validation init container are not covered.

## Release gate

The gate installs istiod (ambient), this chart and ztunnel from this repository into kind, puts a
client and a server in an ambient namespace, and passes only when the request succeeds AND
ztunnel logs that connection with SPIFFE identities on both ends over HBONE (mutual TLS).

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Cilium

[Cilium](https://cilium.io) is an eBPF-based CNI: it gives pods their addresses, connects
them across nodes and enforces Kubernetes and Cilium network policy. This chart runs the
Cilium agent as a DaemonSet on the QuenchWorks cilium image (built from the cilium/cilium
source on Wolfi, 0 fixable CVEs, cosign-signed, pinned by digest) and installs the
[QuenchWorks Cilium Operator](https://github.com/quenchworks/charts/tree/main/quench/cilium-operator)
chart with it, so one release is a complete Cilium.

## Install

Cilium is the cluster's network, so the cluster must start without another CNI (kind:
`networking.disableDefaultCNI: true`). Install once per cluster, in `kube-system`:

```sh
helm install cilium oci://ghcr.io/quenchworks/charts/cilium -n kube-system
kubectl get ciliumnodes
kubectl -n kube-system exec ds/cilium -- cilium-dbg status --brief
```

Nodes turn Ready once their agent is up.

## What it configures

Cluster-pool IPAM (the operator hands each node a `/24` of `10.0.0.0/8`), a VXLAN overlay,
IPv4 masquerading, Kubernetes NetworkPolicy and CiliumNetworkPolicy, and kube-proxy left in
place. The settings land in the `cilium-config` ConfigMap, which the agents and the
operator both read; the name is fixed.

Not included: Hubble and its relay, the Envoy L7 proxy (the image ships no Envoy, so
`enable-l7-proxy` is off and L7 policy is unavailable), clustermesh, IPv6 and cloud IPAM
modes.

## Values

| Key | Default | Meaning |
|---|---|---|
| `config.ipam.clusterPoolIPv4CIDR` | `10.0.0.0/8` | pod address range |
| `config.ipam.clusterPoolIPv4MaskSize` | `24` | per-node block size |
| `config.routingMode` | `tunnel` | `tunnel` (overlay) or `native` |
| `config.tunnelProtocol` | `vxlan` | `vxlan` or `geneve` |
| `config.kubeProxyReplacement` | `"false"` | `"true"` also needs `k8s-service-host`/`k8s-service-port` in `extraConfig` |
| `config.policyEnforcementMode` | `default` | `default`, `always` or `never` |
| `config.extraConfig` | `{}` | any other cilium-config key; overrides the chart's |
| `cilium-operator.enabled` | `true` | the operator subchart; its values go under this key |
| `resources` | 100m / 256Mi, 1Gi limit | agent resources (`GOMEMLIMIT` follows the limit) |
| `tolerations` | everything | an agent runs on every node |

## Privileges

Like upstream, the agent and its init containers run as root on the host network with
the capabilities they need to program the node (NET_ADMIN, SYS_ADMIN, BPF maps on the
host's bpffs, the CNI plugin and config written to the host). Treat the release as part
of the node.

## Release gate

The gate starts a two-node kind cluster with no CNI, installs this chart, and requires every
CiliumNode to get a pod CIDR, every node to turn Ready, `cilium-dbg status` to report the
agent OK with both nodes reachable over the overlay, CoreDNS to answer a pod on the other
node, and no agent restarts.

The chart depends on the `quench-common` and `cilium-operator` charts from
`oci://ghcr.io/quenchworks/charts`.

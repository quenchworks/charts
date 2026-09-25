# Cilium Operator

The [Cilium Operator](https://docs.cilium.io/en/stable/internals/cilium_operator/) runs
the cluster-wide half of Cilium: it registers Cilium's CRDs, hands each CiliumNode its
pod CIDR (cluster-pool IPAM), garbage-collects stale identities and endpoints, and
removes the not-ready taint once a node's agent is up. This chart runs the generic
variant on the QuenchWorks cilium-operator image. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest. The cloud IPAM variants (AWS, Azure, Alibaba Cloud)
are not built.

## Install

Install Cilium with its own operator off, then this chart in the same namespace:

```sh
helm install cilium cilium/cilium -n kube-system --set operator.enabled=false
helm install cilium-operator oci://ghcr.io/quenchworks/charts/cilium-operator -n kube-system
kubectl get ciliumnodes
```

The operator reads Cilium's own `cilium-config` ConfigMap (`ciliumConfigMap`), so IPAM
mode, cluster name and CIDRs come from the Cilium install. Keep the chart on the same
Cilium minor line as the agents.

## Why it runs on the host network

Nodes get their pod CIDRs from the operator, so the operator has to run before the pod
network exists. Like upstream, the chart sets `hostNetwork: true`, tolerates not-ready
and control-plane nodes, and uses `system-cluster-critical`. Health listens on host port
9234, so the rollout replaces one replica at a time and the replicas spread across nodes.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `2` | one leader, one standby (leader election on a Lease) |
| `ciliumConfigMap` | `cilium-config` | Cilium's ConfigMap |
| `metrics.enabled` | `false` | Prometheus metrics on `metrics.port` (9963) |
| `extraArgs` | `[]` | other operator flags |
| `podDisruptionBudget.enabled` | `true` | when `replicas` is above 1 |
| `rbac.create` | `true` | the ClusterRole Cilium 1.20 needs |

Pods run with a read-only root filesystem and all capabilities dropped. The ClusterRole
covers the features Cilium enables by default; features that need more (TLS
interception, ztunnel) are not covered.

The release gate starts a two-node kind cluster, installs upstream Cilium 1.20.2 agents
with their operator off, installs this chart, and requires the CRDs to be registered,
every CiliumNode to get a pod CIDR, every node to turn Ready, CoreDNS to resolve from a
pod, and one replica to hold the leader lease.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

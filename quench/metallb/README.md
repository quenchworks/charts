# MetalLB

[MetalLB](https://metallb.io) gives Kubernetes clusters without a cloud load balancer
(bare metal, on-prem, edge, kind) working `type: LoadBalancer` Services. The controller
assigns each Service an address from your `IPAddressPool`s, and the speaker DaemonSet
announces it over L2 (ARP/NDP) or BGP.

This chart runs MetalLB 0.16.0 on QuenchWorks images built from source: 0 fixable CVEs,
cosign-signed, pinned by digest. It uses MetalLB's native L2/BGP implementation; FRR
mode (which needs the separate FRR daemon) is not included.

## Install

```sh
helm install metallb oci://ghcr.io/quenchworks/charts/metallb -n metallb-system --create-namespace
```

MetalLB hands out nothing until it has addresses:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata: { name: default, namespace: metallb-system }
spec:
  addresses: ["192.168.10.240-192.168.10.250"]
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata: { name: default, namespace: metallb-system }
```

For BGP, add a `BGPPeer` and a `BGPAdvertisement` instead of (or beside) the
L2Advertisement.

## What it deploys

- The MetalLB CRDs (`IPAddressPool`, `L2Advertisement`, `BGPPeer`, `BGPAdvertisement`,
  `Community`, `BFDProfile`, and the status CRDs), verbatim from upstream 0.16.0.
- The controller Deployment, which also serves the CRD validation webhook and rotates
  its certificate itself. The webhook configuration, Service and Secret use MetalLB's
  fixed names (`metallb-webhook-*`), so install one MetalLB per cluster.
- The speaker DaemonSet on the host network. It runs as uid 0 with `NET_RAW` as its only
  capability (L2 needs raw sockets, and a non-root process does not get an added
  capability), a read-only root filesystem and no privilege escalation. The controller
  runs as uid 1001 with all capabilities dropped.

## Values

| Key | Default | Meaning |
|---|---|---|
| `loadBalancerClass` | `""` | only handle Services with this `loadBalancerClass` |
| `crds.enabled` | `true` | install the CRDs with the chart |
| `webhook.failurePolicy` | `Fail` | API server behaviour when the webhook is down |
| `speaker.enabled` | `true` | run the speaker DaemonSet |
| `speaker.ignoreExcludeLB` | `false` | also announce from nodes labeled `node.kubernetes.io/exclude-from-external-load-balancers` (set `true` on kind) |
| `speaker.tolerateControlPlane` | `true` | run speakers on control-plane nodes |
| `speaker.memberlist.enabled` | `true` | fast dead-node detection between speakers |
| `speaker.excludeInterfaces.patterns` | virtual/CNI links | interfaces L2 mode never announces on |
| `metricsPort` | `7472` | authenticated HTTPS metrics on both components |

The release gate installs the chart on kind, creates a pool and an L2Advertisement,
exposes a real HTTP backend as a LoadBalancer Service, and requires the assigned address
to answer from outside the cluster, which only happens if the speaker's ARP
announcement works.

The chart depends on the `quench-common` library chart from
`oci://ghcr.io/quenchworks/charts`.

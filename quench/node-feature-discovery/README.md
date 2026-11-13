# Quenchworks node-feature-discovery

[Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery)
0.20.1 on the QuenchWorks image (built from source, nonroot, CVE-gated at build,
pinned by digest, cosign-signed). It labels every node with its hardware, kernel
and OS features (`feature.node.kubernetes.io/*`), and adds your own labels from
`NodeFeatureRule` resources, so workloads can be scheduled onto the hardware they
need.

The chart is upstream's default deployment (`deployment/overlays/default` at
v0.20.1) with the namespace and the image templated: nfd-master, the nfd-worker
DaemonSet with its read-only host mounts, nfd-gc, upstream's RBAC and worker
configuration, and the three CRDs (`NodeFeature`, `NodeFeatureRule`,
`NodeFeatureGroup`).

## Install

```bash
helm install nfd oci://ghcr.io/quenchworks/charts/node-feature-discovery -n node-feature-discovery --create-namespace
```

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` / `.digest` | our image | one image runs master, worker and gc |

The worker configuration is upstream's `nfd-worker-conf` ConfigMap. To change
sources or label rules, edit `templates/nfd.yaml` in a fork, or use
`NodeFeatureRule` resources, which need no restart.

## Notes

- Object names are upstream's (`nfd-master`, `nfd-worker`, `nfd-gc`, `nfd-*`
  ClusterRoles), so install it once per cluster.
- The worker reads the host through read-only mounts under `/host-*`
  (`/host-sys`, `/host-boot`, `/host-etc/os-release`, `/host-proc/swaps`,
  `/host-usr/lib`, `/host-lib`), as upstream's does.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across releases.

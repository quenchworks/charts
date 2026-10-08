# Quenchworks Calico

[Project Calico](https://github.com/projectcalico/calico) 3.32.0 networking and network
policy, installed by the [Tigera operator](https://github.com/tigera/operator) 1.42.2 (the
operator release that deploys Calico 3.32.0). Every image is built from source by
QuenchWorks on Wolfi, 0-CVE, cosign-signed, and pinned by digest.

```sh
helm install calico oci://ghcr.io/quenchworks/charts/calico -n tigera-operator --create-namespace
kubectl get tigerastatus
```

Install it on a cluster without a CNI (for kind: `networking.disableDefaultCNI: true`). The
operator runs on the host network and tolerates not-ready nodes, since it is what makes
them ready. It installs its own CRDs (`-manage-crds`); a post-install hook Job, also on the
host network, applies two cluster-scoped resources once those CRDs exist:

- `ImageSet calico-v3.32.0`, which pins `calico/node`, `cni`, `kube-controllers` and `typha`
  to QuenchWorks digests;
- `Installation default`, with `registry: ghcr.io/`, `imagePath: quenchworks/images` and
  `imagePrefix: calico-`, so the operator pulls `ghcr.io/quenchworks/images/calico-node` etc.

The hook resources are not release objects: `helm uninstall` leaves Calico running. Remove
it with `kubectl delete installation default` before uninstalling the operator.

## Values

| Key | Default | Notes |
|---|---|---|
| `installation.enabled` | `true` | Apply the Installation; set false to manage it yourself |
| `installation.podCIDR` | `192.168.0.0/16` | Default IPv4 pool; must match the cluster's pod CIDR |
| `installation.encapsulation` | `VXLANCrossSubnet` | `IPIP`, `VXLAN`, `None`, ... |
| `installation.spec` | `{}` | Merged over the Installation spec the chart builds |
| `calicoImages` | QuenchWorks digests | The ImageSet entries |

Not deployed in this release: the Calico API server, Goldmane/Whisker (each only for its
own CR) and the CSI node driver (`kubeletVolumePluginPath: None`).

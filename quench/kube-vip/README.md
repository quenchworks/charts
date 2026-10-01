# Quenchworks kube-vip

Hardened [kube-vip](https://github.com/kube-vip/kube-vip) on a minimal 0-CVE
image, built from source and pinned by digest.

kube-vip runs on every node and announces virtual IPs: addresses for Services of
type LoadBalancer, and optionally one in front of the Kubernetes API servers. In
ARP mode one node answers for each address on the local network; in BGP mode
the nodes advertise it to your routers.

## Install

```sh
helm install kube-vip oci://ghcr.io/quenchworks/charts/kube-vip -n kube-vip --create-namespace
```

Then give a Service an address from your node network:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
  annotations:
    kube-vip.io/loadbalancerIPs: "192.168.1.200"
spec:
  type: LoadBalancer
  selector: { app: web }
  ports: [ { port: 80, targetPort: 8080 } ]
```

For pools that hand out addresses automatically, run the kube-vip cloud provider
alongside it.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/kube-vip \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/kube-vip --owner quenchworks`.

## Security model

kube-vip adds addresses to the node's interface and answers ARP, so the pod runs
on the host network with NET_ADMIN and NET_RAW. Linux drops added capabilities
for a non-root process, so this container runs as uid 0, with every other
capability dropped and a read-only root filesystem.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `mode` | `arp` | `arp` (layer 2) or `bgp` (set peers with `extraArgs`). |
| `interface` | `""` | Interface for the addresses; empty uses the default route's. |
| `services.enabled` | `true` | Load balancer for Services of type LoadBalancer. |
| `controlPlane.enabled`, `.address`, `.port` | off, `""`, `6443` | A virtual IP for the API servers. |
| `metricsPort` | `2112` | Prometheus metrics on the host network. |
| `extraArgs` | `[]` | Appended to `kube-vip manager`. |
| `tolerations` | control-plane | Run on control-plane nodes too. |

Leader election is on, so each address is announced by one node at a time.

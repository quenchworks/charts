# Quenchworks derper

Hardened [derper](https://tailscale.com/kb/1118/custom-derp-servers), Tailscale's DERP relay: when two
tailnet nodes cannot reach each other directly, they relay their (end-to-end encrypted) WireGuard traffic
through a DERP server, and use its STUN service for NAT traversal. Run your own region for Tailscale or
for [Headscale](https://quench-works.com). The image is built from the Tailscale source; it runs as uid
1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install derp oci://ghcr.io/quenchworks/charts/derper --set hostname=derp.example.com \
  --set service.type=LoadBalancer \
  --set tls.certManager.enabled=true --set tls.certManager.issuerRef.name=letsencrypt \
  --set 'tls.certManager.dnsNames={derp.example.com}'
```

derper serves TLS only on port 443. The chart lets the nonroot user bind it with the safe sysctl
`net.ipv4.ip_unprivileged_port_start=0` (in `podSecurityContext`) instead of running as root. Expose
443/tcp and 3478/udp (a LoadBalancer Service is the usual way), point DNS for `hostname` at it, then add
the region to your DERP map (Tailscale ACLs or Headscale's `derp.paths`).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `hostname` | required | The relay's DNS name (clients connect with this SNI) |
| `stun.enabled` | `true` | STUN on 3478/udp |
| `verifyClients` | `false` | Relay only for your tailnet's nodes (needs a tailscaled sidecar) |
| `extraArgs` | `[]` | More derper flags |
| `tls` | enabled | Certificate source: existing Secret, cert-manager, or a Helm-made CA (testing only) |
| `service.type` | `ClusterIP` | Use `LoadBalancer` to reach it from the internet |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/derper \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

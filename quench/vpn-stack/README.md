# Quenchworks VPN stack

A self-hosted VPN in one install: [NetBird](https://github.com/netbirdio/netbird) (a WireGuard mesh with single
sign-on, access policies and routing peers) on a highly available PostgreSQL, a 3-member Patroni cluster that
elects its leader through the Kubernetes API and fails over on its own. Every image is QuenchWorks-hardened,
built from source, nonroot, CVE-gated, pinned by digest and cosign-signed.

## Install

```bash
helm install vpn oci://ghcr.io/quenchworks/charts/vpn-stack \
  --set netbird.domain=netbird.example.com \
  --set netbird.owner.email=you@example.com \
  --set netbird.ingress.enabled=true --set netbird.ingress.className=nginx \
  --set 'netbird.ingress.tls[0].hosts[0]=netbird.example.com' \
  --set 'netbird.ingress.tls[0].secretName=netbird-tls'
kubectl get secret vpn-netbird -o jsonpath='{.data.owner-password}' | base64 -d; echo
```

Every `netbird.*` value of the [netbird chart](https://quench-works.com/charts/netbird) applies, including the
routing peers (`netbird.router.*`).

## What stays up

| Part | Replicas | During a failure or an upgrade |
|---|---|---|
| PostgreSQL | 3 (Patroni) | Losing the leader promotes a replica in seconds; the Service follows the new leader |
| Dashboard | 2 | Rolls one pod at a time |
| Management, signal | 1 each | Restart in seconds; new logins and new peer connections wait, tunnels already up keep running |
| Relay | 1 | Peers that need a relay reconnect after it restarts |
| Peer traffic | direct WireGuard | Not routed through the control plane, so it keeps flowing |

Running management and signal active-active (several replicas behind a load balancer) is a NetBird Enterprise
feature (it adds NATS and Redis); the open-source build runs one of each. The stack's release gate kills the
database leader and checks that NetBird still serves sign-in and its data afterwards.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/netbird-management \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

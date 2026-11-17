# Quenchworks NetBird

Hardened [NetBird](https://github.com/netbirdio/netbird): a WireGuard mesh VPN with single sign-on, access
policies, DNS and routing peers. Every image is built from source (management, signal, relay, the client and the
dashboard), runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

The chart runs the self-hosted layout as separate services: **management** (the API and control plane, with
NetBird's built-in sign-in, Dex, so no external identity provider is needed), **signal**, **relay** and the
**dashboard**, on the bundled QuenchWorks PostgreSQL. One public host serves everything, routed by path.
Optional **routing peers** (the NetBird client) join with a setup key and route networks for the mesh.

## Install

```bash
helm install vpn oci://ghcr.io/quenchworks/charts/netbird \
  --set domain=netbird.example.com \
  --set owner.email=you@example.com \
  --set ingress.enabled=true --set ingress.className=nginx \
  --set 'ingress.tls[0].hosts[0]=netbird.example.com' --set 'ingress.tls[0].secretName=netbird-tls'
kubectl get secret vpn-netbird -o jsonpath='{.data.owner-password}' | base64 -d; echo
```

Open `https://netbird.example.com`, sign in as the owner, then create setup keys for peers.

The ingress needs gRPC to management and signal: the chart creates a second Ingress for those paths with
`ingress.grpcAnnotations` (ingress-nginx's `backend-protocol: GRPC` by default; set your controller's equivalent).

## Routing peers

Create a reusable setup key in the dashboard, store it in a Secret, and enable the router:

```bash
kubectl create secret generic netbird-router --from-literal=setup-key=<key>
helm upgrade vpn oci://ghcr.io/quenchworks/charts/netbird --reuse-values \
  --set router.enabled=true --set router.setupKey.existingSecret=netbird-router
```

By default the router runs in userspace (netstack) mode as uid 1001. `router.kernelMode=true` uses kernel
WireGuard and iptables (root with NET_ADMIN), and `router.hostNetwork=true` gives it the node's network, as a
router-host would.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | required | The public host for the dashboard, API, sign-in, signal and relay |
| `publicScheme` | `https` | `http` only for testing |
| `owner.email` / `owner.password` | `admin@example.com` / generated | The first administrator |
| `secret.existingSecret` | `""` | Your own relay secret, store key, cookie key and owner password and hash |
| `management.dnsDomain` | `netbird.selfhosted` | Appended to peer names |
| `stunServers` | Google's public STUN | What peers use to find their public address |
| `router.*` | off | Routing peers |
| `postgresql.enabled` | `true` | The bundled PostgreSQL; or `externalDatabase.*` |
| `ingress.*` | off | One host, path routing, plus a gRPC Ingress |

The store encryption key in the Secret encrypts sensitive data in the database: back it up with the database.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/netbird-management \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks OpenZiti

Hardened [OpenZiti](https://github.com/openziti/ziti), a zero-trust overlay network that
replaces VPNs and open inbound ports, on a minimal, shell-free, nonroot, CVE-gated image built
from source, cosign-signed and pinned by digest.

This chart runs one pod with an OpenZiti controller (PKI, database, edge API) and an
integrated edge router, both on a persistent volume: a complete small network. The PKI, the
router identity and the database survive restarts and upgrades. It is one replica by design.

## Install

```bash
helm install ziti oci://ghcr.io/quenchworks/charts/openziti \
  --set advertisedHost=ziti.example.com --set service.type=LoadBalancer
```

`advertisedHost` is the name clients, tunnelers and the router use for the controller and the
router, and it goes into the certificates: set it on the first install. Empty means the
release's Service DNS name, reachable from inside the cluster only.

Ports, both TLS: the edge API on `controller.port` (1280) and the edge router on
`router.port` (3022).

## Log in

The `admin` password is generated into `<release>-openziti-admin` on first install (kept on
uninstall, since the controller sets it once), or comes from `admin.password` or
`admin.existingSecret` (key `password`, at least 5 characters):

```bash
kubectl exec sts/ziti-openziti -- ziti edge login ziti.example.com:1280 -u admin -y \
  -p "$(kubectl get secret ziti-openziti-admin -o jsonpath='{.data.password}' | base64 -d)"
kubectl exec sts/ziti-openziti -- ziti edge list edge-routers
```

Then create identities, services and policies with `ziti edge create ...`, and enroll tunnelers
and SDK clients with the identities' JWTs.

## Not included

A multi-node controller cluster (raft) and separately scaled edge routers: this chart is one
controller with one integrated router.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/openziti \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

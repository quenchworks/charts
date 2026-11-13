# Quenchworks apisix-hybrid-stack

Apache APISIX in decoupled (hybrid) mode, from QuenchWorks images (nonroot,
CVE-gated at build, pinned by digest, cosign-signed):

| Component | Chart | Role |
|---|---|---|
| control plane | `apisix` (`role: control_plane`) | the Admin API on 9180; writes routes into etcd. ClusterIP only |
| data plane | `apisix` (`role: data_plane`) | the proxy on 9080 / 9443, 2 replicas; reads routes from etcd, runs no Admin API |
| etcd | `etcd` | 3 members; the client port requires a certificate signed by the stack's CA |
| ingress controller | `apisix-ingress-controller` | turns Ingress, ApisixRoute and HTTPRoute objects into Admin API calls on the control plane |
| Gateway API CRDs | `gateway-api-crds` | v1.6.1 standard channel; the controller needs them even for plain Ingress |

The data planes only need etcd. With the control plane down they keep serving,
and a restarted data plane loads every route from etcd again.

## Install

```bash
helm install gw oci://ghcr.io/quenchworks/charts/apisix-hybrid-stack -n apisix --create-namespace
```

Expose the proxy with `dataPlane.service.type: LoadBalancer` (or your own
Ingress or Gateway in front of `apisix-data-plane`). Keep the control plane
internal.

## Values

| Key | Default | Notes |
|---|---|---|
| `etcdTLS.create` | `true` | generate the etcd CA, server and client certificates once and keep them |
| `etcdTLS.validityDays` | `3650` | lifetime of the generated CA and certificates |
| `etcd.replicaCount` | `3` | odd numbers only; quorum is (N/2)+1 |
| `dataPlane.replicaCount` | `3` | proxy replicas |
| `dataPlane.service.type` | `ClusterIP` | `LoadBalancer` to take traffic from outside |
| `apisix-ingress-controller.enabled` | `true` | IngressClass `apisix` |
| `gatewayAPICRDs.enabled` | `true` | `false` when another release already owns the Gateway API CRDs |

Everything under `controlPlane`, `dataPlane`, `etcd` and
`apisix-ingress-controller` goes to that chart; see its README for the rest.

## Notes

- Object names are fixed (`apisix-control-plane`, `apisix-data-plane`,
  `apisix-etcd`) so the parts find each other without templating: install one
  stack per namespace.
- The generated certificate Secrets (`apisix-etcd-server-tls`,
  `apisix-etcd-client-tls`) carry `helm.sh/resource-policy: keep`, so
  `helm uninstall` leaves them behind. To rotate, delete both, run
  `helm upgrade`, then restart `apisix-etcd`, `apisix-control-plane` and
  `apisix-data-plane`.
- To bring your own certificates set `etcdTLS.create: false` and create both
  Secrets (`tls.crt`, `tls.key`, `ca.crt`). The server certificate must cover
  `apisix-etcd` and `*.apisix-etcd-headless.<namespace>.svc`, and allow client
  auth (the etcd probe presents it).
- The admin key is generated into `apisix-control-plane-admin` (key
  `admin-key`); the ingress controller reads it from there.

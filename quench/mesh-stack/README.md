# Quenchworks mesh-stack

An [Istio ambient](https://istio.io/latest/docs/ambient/) service mesh in one install: every pod
in a labelled namespace gets a SPIFFE identity and talks mutual TLS through its node's ztunnel,
with no sidecars and no restarts. All images are QuenchWorks builds: 0-CVE, pinned by digest and
cosign-signed.

| Component | Chart | Name in the cluster |
|---|---|---|
| istiod 1.30.5 (control plane, CA) | istiod 0.0.6 | Deployment and Service `istiod` |
| Istio CNI node agent 1.30.5 | istio-cni 0.0.2 | DaemonSet `istio-cni-node` |
| ztunnel 1.30.5 (L4 proxy) | ztunnel 0.0.2 | DaemonSet `ztunnel` |

## Install

```bash
helm install mesh oci://ghcr.io/quenchworks/charts/mesh-stack -n istio-system --create-namespace
kubectl label namespace <ns> istio.io/dataplane-mode=ambient
kubectl -n istio-system logs ds/ztunnel | grep 'connection complete'
```

The stack wires ambient once: istiod is named `istiod` (ztunnel's default address), runs with
`PILOT_ENABLE_AMBIENT=true`, and trusts `istio-system/ztunnel` to request certificates for the
pods on its node. It must go into `istio-system`; the install refuses any other namespace.

The node's own CNI keeps doing pod networking; istio-cni chains itself after it. Opt one pod out
of a meshed namespace with the label `istio.io/dataplane-mode=none`.

## Not included

Waypoint proxies (L7 routing and policy) and ingress/egress gateways, which need Istio's Envoy
proxy image; Istio's CRDs (PeerAuthentication, AuthorizationPolicy, ...), so policies are not
available yet. Values for each component go under `istiod`, `istio-cni` and `ztunnel`.

## Release gate

The gate installs this stack into kind, meshes a namespace, and passes only when a client's
request to a server succeeds AND ztunnel logs that connection over HBONE with SPIFFE identities on
both ends (mutual TLS).

The chart depends on the `quench-common`, `istiod`, `istio-cni` and `ztunnel` charts from
`oci://ghcr.io/quenchworks/charts`.

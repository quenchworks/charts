# Hubble UI

[Hubble UI](https://github.com/cilium/hubble-ui) is Cilium's web UI for the service map
and live network flows. This chart runs the frontend (nginx serving the React bundle)
and the backend (a Go service that reads Hubble Relay) in one pod, on the QuenchWorks
hubble-ui and hubble-ui-backend images. Both are nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

It needs Hubble Relay, for example the QuenchWorks hubble-relay chart next to a Cilium
install with Hubble enabled.

## Install

```sh
helm install hubble-relay oci://ghcr.io/quenchworks/charts/hubble-relay -n kube-system --set fullnameOverride=hubble-relay
helm install hubble-ui oci://ghcr.io/quenchworks/charts/hubble-ui -n kube-system
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
# open http://127.0.0.1:12000/
```

`relay.address` is the relay's gRPC address (default
`hubble-relay.kube-system.svc.cluster.local:80`). With the relay's server TLS on, set
`relay.tls.enabled` and `relay.tls.existingSecret` (keys `ca.crt`, `tls.crt`, `tls.key`).

## Security

The UI has no login: anyone who reaches the Service sees every flow in the cluster. Keep
the Service internal or put an authenticating proxy in front. The backend's ClusterRole
is read-only (namespaces, pods, services, nodes, CRDs), the same resources upstream grants.

## Values

| Key | Default | Meaning |
|---|---|---|
| `relay.address` | `hubble-relay.kube-system.svc.cluster.local:80` | Hubble Relay |
| `relay.tls.enabled` | `false` | TLS to the relay |
| `service.port` | `80` | UI port |
| `rbac.create` | `true` | the backend's read-only ClusterRole |

Both containers run with a read-only root filesystem and all capabilities dropped.

The release gate starts a two-node kind cluster with upstream Cilium and the QuenchWorks
hubble-relay chart, installs this chart, and requires the UI to load and a gRPC-Web
status call from the browser path (nginx, backend, relay) to succeed.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

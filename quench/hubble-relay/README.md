# Hubble Relay

[Hubble Relay](https://docs.cilium.io/en/stable/observability/hubble/) aggregates the
Hubble servers that run inside every Cilium agent into one Observer API, so the `hubble`
CLI and Hubble UI see network flows across the whole cluster. This chart runs it on the
QuenchWorks hubble-relay image. The image is nonroot, 0 fixable CVEs, cosign-signed and
pinned by digest.

It needs an existing Cilium install with Hubble enabled. Turn off Cilium's own relay
(`hubble.relay.enabled=false`) and install this one in Cilium's namespace.

## Install

```sh
helm install hubble-relay oci://ghcr.io/quenchworks/charts/hubble-relay -n kube-system
kubectl -n kube-system port-forward svc/hubble-relay 4245:80
hubble status --server localhost:4245
hubble observe --server localhost:4245 --last 20
```

## TLS

Cilium turns Hubble TLS on by default. The relay then dials the peer service on 443 and
authenticates to each Hubble server with the client certificate in
`tls.client.existingSecret` (keys `ca.crt`, `tls.crt`, `tls.key`). Cilium's certgen
creates that Secret as `hubble-relay-client-certs` when its relay is enabled, or once
through `hubble.tls.auto`. With Hubble TLS off, set `peerService` to port 80 and
`tls.client.enabled=false`.

`tls.server` puts TLS on the relay's own API for the CLI and Hubble UI.

## Values

| Key | Default | Meaning |
|---|---|---|
| `peerService` | `hubble-peer.kube-system.svc.cluster.local:443` | the agents' peer service |
| `clusterName` | `default` | must match Cilium's `cluster.name` |
| `tls.client.enabled` | `true` | mTLS to the Hubble servers |
| `tls.client.existingSecret` | `hubble-relay-client-certs` | the client certificate |
| `tls.server.enabled` | `false` | TLS on the relay API |
| `metrics.enabled` | `false` | Prometheus metrics on `metrics.port` (9966) |
| `service.port` | `80` | relay API port |

Pods run with a read-only root filesystem, all capabilities dropped and no service
account token. Readiness is the gRPC health service on 4222, which reports SERVING
once at least one Hubble peer is connected.

The release gate starts a two-node kind cluster with upstream Cilium 1.20.2 as the CNI,
installs this chart, and requires the relay to become ready, the `hubble` CLI to report
both nodes connected, and flows to come back through it.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

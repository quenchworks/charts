# Kubo (IPFS)

[Kubo](https://github.com/ipfs/kubo) is the reference IPFS node: it stores and serves
content by its hash (CID) and exchanges blocks with other peers over libp2p. This chart
runs it on the QuenchWorks kubo image as a StatefulSet with a PVC that holds the repo and
the node's identity key. The image is nonroot, 0 fixable CVEs, cosign-signed and pinned
by digest.

## Install

```sh
helm install ipfs oci://ghcr.io/quenchworks/charts/kubo
kubectl port-forward svc/ipfs-kubo 5001 8080 &
curl -X POST -F file=@README.md "http://127.0.0.1:5001/api/v0/add?cid-version=1"
curl http://127.0.0.1:8080/ipfs/<cid>
```

The RPC API on 5001 has no authentication and full control of the node (add, pin,
config, shutdown). Keep it cluster-internal and expose only the gateway.

## Values

| Key | Default | Meaning |
|---|---|---|
| `profile` | `server` | init profiles, applied once when the repo is created |
| `swarmKey.existingSecret` | `""` | a Secret with a `swarm.key` key: a private IPFS network, installed on first boot |
| `extraArgs` | `[]` | extra `ipfs daemon` flags, e.g. `--enable-gc` |
| `persistence.enabled` | `true` | a PVC for `/data/ipfs` (blocks, config, identity) |
| `persistence.size` | `20Gi` | PVC size |
| `service.gatewayPort` / `service.apiPort` | `8080` / `5001` | gateway and RPC API on the ClusterIP Service |
| `swarm.service.enabled` | `false` | a Service for inbound libp2p on 4001 (TCP and QUIC) |

The `server` profile stops Kubo dialing private address ranges and turns off mDNS, which
is right on a cluster network. Profiles and config are written into the repo on first
boot only; change them later with `kubectl exec ... -- ipfs config` and restart the pod.

Without the swarm Service the node still dials out, fetches from peers and serves the
peers it is connected to. For inbound peers, enable it with a LoadBalancer or NodePort
and set `Addresses.Announce` to the public address.

The chart runs one node. Pods run with a read-only root filesystem and all capabilities
dropped.

The release gate installs the chart on kind with persistence on, checks the reported
version against the chart's appVersion, adds a block through the RPC API and reads it back
through the gateway Service, checks the `server` profile's address filters, deletes the
pod, and requires the same PeerID and the block to be back after the restart.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

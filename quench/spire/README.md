# SPIRE

[SPIRE](https://github.com/spiffe/spire) is the SPIFFE runtime. The server issues
short-lived X.509 and JWT identities (SVIDs); an agent on each node attests the node to
the server and attests each workload that calls it, then serves that workload its SVID
over the Workload API socket. This chart runs both from the QuenchWorks spire image,
0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install spire oci://ghcr.io/quenchworks/charts/spire -n spire --create-namespace \
  --set trustDomain=example.org --set clusterName=prod
```

Then register workloads (NOTES.txt prints these for your release): one node alias that
covers every agent in the cluster, and an entry per workload under it, selected by
namespace and service account.

```sh
kubectl exec -n spire spire-server-0 -- spire-server entry create -node \
  -spiffeID spiffe://example.org/ns/spire/agents -selector k8s_psat:cluster:prod
kubectl exec -n spire spire-server-0 -- spire-server entry create \
  -parentID spiffe://example.org/ns/spire/agents \
  -spiffeID spiffe://example.org/ns/shop/sa/api -selector k8s:ns:shop -selector k8s:sa:api
```

A workload mounts the agent's socket directory (`agent.socketDir`, default
`/run/spire/agent-sockets`) and fetches its SVID from `agent.sock`, directly or through a
SPIFFE library or Envoy's SDS.

## What runs

- `spire-server`, a StatefulSet with one replica: sqlite datastore and CA keys on a PVC,
  k8s_psat node attestation, and the trust bundle published to the `<release>-bundle`
  ConfigMap, which the agents bootstrap from. Nonroot, read-only root filesystem.
- `spire-agent`, a DaemonSet on every node: attests with a projected service account
  token (k8s_psat), attests pods through the kubelet (k8s) and processes (unix).

The agent is a node agent and runs with hostPID and as root, because the Workload API
identifies callers by PID and creates its socket in a root-owned host directory. It drops
every capability, disallows privilege escalation and keeps a read-only root filesystem.

## Values

| Key | Default | Meaning |
|---|---|---|
| `trustDomain` | `example.org` | SPIFFE trust domain |
| `clusterName` | `kubernetes` | k8s_psat cluster name, part of each agent's ID |
| `server.caTTL` / `server.defaultX509SVIDTTL` | `24h` / `1h` | CA and SVID lifetimes |
| `server.persistence.*` | `1Gi` PVC | datastore and keys |
| `agent.socketDir` | `/run/spire/agent-sockets` | host directory for the Workload API socket |
| `agent.hostNetwork` | `false` | reach the kubelet on localhost where node names do not resolve |

Registration is manual (the server CLI). The SPIRE Controller Manager and the SPIFFE CSI
driver are not part of this chart.

The release gate installs the chart on kind, requires the trust bundle in its ConfigMap
and one k8s_psat agent per node, registers a node alias and a workload entry, requires a
pod attested by the k8s attestor to receive that SVID over the socket, deletes the server
pod, and requires the entry to be back.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

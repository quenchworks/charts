# Linkerd CNI

The [Linkerd CNI plugin](https://linkerd.io/2/features/cni/): a DaemonSet that chains the
`linkerd-cni` plugin into each node's CNI configuration, so every pod Linkerd injects gets its
traffic redirected to its proxy when it starts, without the privileged `linkerd-init` container.
It runs on the QuenchWorks linkerd-cni image (built from linkerd/linkerd2-proxy-init on Wolfi,
0 fixable CVEs, cosign-signed, pinned by digest).

## Install

Install it before the QuenchWorks linkerd chart, which runs its data plane in CNI mode:

```sh
helm install linkerd-cni oci://ghcr.io/quenchworks/charts/linkerd-cni -n linkerd-cni --create-namespace --wait
```

Then follow the linkerd chart's README. Pods started before the plugin was installed are not
redirected until they restart.

## Values

| Key | Default | Meaning |
|---|---|---|
| `proxy.inboundPort` / `outboundPort` / `uid` | `4143` / `4140` / `2102` | must match the injected proxy |
| `proxy.ignoreInboundPorts` | `["4191","4190"]` | the proxy's admin and control ports |
| `proxy.ignoreOutboundPorts` | `[]` | outbound ports never redirected |
| `iptablesMode` | `nft` | `nft` or `legacy`, matching the node |
| `cniBinDir` / `cniConfDir` | `/opt/cni/bin` / `/etc/cni/net.d` | the node's CNI paths |

Per-pod overrides use Linkerd's usual annotations (`config.linkerd.io/skip-outbound-ports`, ...).

## Privileges

The installer runs as root (the image user) because it writes the node's CNI bin and config
directories; it is not privileged and its root filesystem is read-only. Object names are fixed,
so install once per cluster. The CNI repair controller is not deployed.

## Release gate

The gate installs linkerd-crds, this chart and the linkerd chart into kind and passes only when
an injected pod has no `linkerd-init` container and reaches another injected pod over mutual TLS
(`tls="true"` and the server's identity on its proxy's outbound metrics).

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

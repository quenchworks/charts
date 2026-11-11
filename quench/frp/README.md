# Quenchworks frp

Hardened [frp](https://github.com/fatedier/frp) server (frps): a fast reverse proxy that exposes
services behind NAT or a firewall. frpc clients log in to frps and ask it to listen on a port
(tcp/udp proxies) or a domain (http/https virtual hosts) and forward to a service on their side.
One Deployment runs frps with its web dashboard.

The image is built from the upstream release tag (frps and frpc, dashboards built from source and
embedded), runs as nonroot uid 1001, is CVE-gated (the build fails on any fixable CVE), and is
cosign-signed and pinned by digest. The same image runs frpc with `--entrypoint /usr/bin/frpc`.

## Install

```bash
helm install tunnel oci://ghcr.io/quenchworks/charts/frp \
  --set service.type=LoadBalancer \
  --set 'allowPorts[0].start=6000' --set 'allowPorts[0].end=6010' \
  --set 'proxyPorts[0].name=ssh' --set 'proxyPorts[0].port=6000'
kubectl get secret tunnel-frp -o jsonpath='{.data.token}' | base64 -d; echo
```

A client, using the token above:

```toml
serverAddr = "<the LoadBalancer address>"
serverPort = 7000
auth.token = "<token>"

[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000
```

The proxy is reachable on the Service's port 6000 because `proxyPorts` publishes it.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/frp \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/frp@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/frp` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `bindPort` | `7000` | Control port frpc connects to. |
| `auth.token` | `""` | Client token. Empty: generated and kept across upgrades. |
| `auth.existingSecret` | `""` | Secret with keys `token` and `dashboard-password`. |
| `dashboard.enabled` / `port` / `user` / `password` | `true` / `7500` / `admin` / `""` | Web dashboard; empty password is generated. |
| `allowPorts` | `[]` | Ports clients may bind (`{start, end}` or `{single}`); empty: no limit. |
| `proxyPorts` | `[]` | Proxy ports published on the Service and container (`{name, port, protocol}`). |
| `vhostHTTPPort` / `vhostHTTPSPort` | `0` / `0` | Virtual-host ports for http/https proxies (0: off). |
| `subDomainHost` | `""` | Domain suffix for client subdomains. |
| `extraConfig` | `""` | Raw TOML appended to `frps.toml`. |
| `tls.enabled` | `false` | Force TLS on the control channel with the chart's certificate (see below). |
| `service.type` | `ClusterIP` | `LoadBalancer` or `NodePort` for clients outside the cluster. |
| `service.externalTrafficPolicy` | `""` | `Local` keeps client source addresses. |
| `networkPolicy.enabled` / `allowExternal` | `true` / `true` | Ingress to every frps port. |
| `resources` | 50m / 64Mi requests, 1 CPU / 256Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## TLS

frpc encrypts the control channel by default with a throwaway certificate and does not verify
the server. With `tls.enabled=true` frps serves the chart's certificate (an existing Secret,
cert-manager, or a Helm-generated CA) and refuses plain clients; point frpc at the CA to verify:

```toml
transport.tls.enable = true
transport.tls.trustedCaFile = "ca.crt"   # key ca.crt of Secret <release>-frp-tls
transport.tls.serverName = "<release>-frp.<namespace>.svc"
```

For a client outside the cluster, add the public name to `tls.certManager.dnsNames` or bring
your own certificate with `tls.existingSecret`.

## Design

- **One replica, Recreate.** Proxies live in frps memory and each frpc logs in to one server.
- **Secrets stay out of the ConfigMap.** frps reads the token and dashboard password from the
  environment through its own config templating; the generated ones are kept across upgrades.
- **Probes** use the anonymous `/healthz` on the metrics listener (port 7600, also `/metrics`).
- **A config change rolls the pod**: frps reads its config once at start.

frp is Apache-2.0 licensed.

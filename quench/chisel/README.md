# Quenchworks chisel

Hardened [chisel](https://github.com/jpillora/chisel), a TCP/UDP tunnel carried over HTTP and
secured with SSH. Run the server in the cluster and clients reach services behind it (forward
tunnels), expose their own services through it (reverse tunnels) or use it as a SOCKS5 proxy.
The image is built from source, runs as uid 1001 and is CVE-gated at build, cosign-signed and
pinned by digest.

## Install

```bash
helm install tunnel oci://ghcr.io/quenchworks/charts/chisel
kubectl get secret tunnel-chisel -o jsonpath='{.data.password}' | base64 -d
chisel client --auth chisel:<password> http://tunnel-chisel:8080 5432:postgres:5432
```

## Authentication and key

Every client authenticates; there is no open mode. `auth.username` gets a generated password
(kept across upgrades) unless `auth.password` is set. The server's SSH key is generated once
into the same Secret, so its fingerprint stays stable and clients can pin it with
`--fingerprint`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `port` | `8080` | HTTP(S) listener clients connect to |
| `auth.username`, `auth.password` | `chisel`, generated | Client credentials |
| `reverse` | `false` | Allow reverse tunnels (publish their listeners with `extraPorts`) |
| `socks5` | `false` | Allow clients to use the server as a SOCKS5 proxy |
| `extraPorts` | `[]` | `[{name, port, protocol}]` on the Service and container |
| `extraArgs` | `[]` | More `chisel server` flags (`--backend`, `--keepalive`) |
| `tls.enabled` | `false` | TLS on the listener: existing Secret, cert-manager, or self-signed |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/chisel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

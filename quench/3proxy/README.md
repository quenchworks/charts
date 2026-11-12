# Quenchworks 3proxy

Hardened [3proxy](https://github.com/3proxy/3proxy), the tiny multi-protocol proxy suite in C:
HTTP and SOCKS4/5 proxies, POP3 and FTP proxies, and TCP/UDP port mapping. The image is built
from source against Wolfi OpenSSL and PCRE2, runs as uid 1001 and is CVE-gated at build,
cosign-signed and pinned by digest. 3proxy's own license also offers Apache-2.0, which is
how it ships here.

## Install

```bash
helm install egress oci://ghcr.io/quenchworks/charts/3proxy
kubectl get secret egress-3proxy -o jsonpath='{.data.password}' | base64 -d
```

Clients then use `http://proxy:<password>@egress-3proxy:3128` (HTTP proxy) or
`socks5h://proxy:<password>@egress-3proxy:1080`.

## Authentication

Every client authenticates; there is no open mode. `auth.username` gets a generated password
(kept across upgrades) unless `auth.password` is set; `auth.extraUsers` adds more. The rendered
config lives in a Secret.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `http.enabled`, `http.port` | `true`, `3128` | HTTP proxy |
| `socks.enabled`, `socks.port` | `true`, `1080` | SOCKS4/5 proxy |
| `auth.username`, `auth.password` | `proxy`, generated | The default user |
| `auth.extraUsers` | `[]` | More users: `[{name, password}]` |
| `extraConfig` | `""` | Raw 3proxy config appended after the listeners (port maps, limits) |
| `extraPorts` | `[]` | Publish listeners added in `extraConfig` |

Requests to `127.0.0.0/8` are denied, so clients cannot reach services bound to the pod's
loopback through the proxy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/3proxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

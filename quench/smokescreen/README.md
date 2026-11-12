# Quenchworks Smokescreen

Hardened [Smokescreen](https://github.com/stripe/smokescreen), Stripe's egress proxy. Workloads
send outbound HTTP and HTTPS through it; it refuses private, loopback and link-local
destinations (so a server-side request forgery cannot reach internal services or the cloud
metadata endpoint), and an optional egress ACL limits which domains each role may reach. The
image is built from source, runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned
by digest.

## Install

```bash
helm install egress oci://ghcr.io/quenchworks/charts/smokescreen
# in the workload
HTTPS_PROXY=http://egress-smokescreen:4750 HTTP_PROXY=http://egress-smokescreen:4750
```

Inside a cluster every pod and Service IP is private, so Smokescreen reaches the internet and
refuses in-cluster targets until you open them.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `port` | `4750` | HTTP and CONNECT proxy port |
| `allowRanges`, `allowAddresses` | `[]` | Private CIDRs or `IP[:PORT]` to allow |
| `denyRanges`, `denyAddresses` | `[]` | More destinations to refuse |
| `egressAcl` | `{}` | Per-role egress ACL (YAML), roles from client certificates or `X-Smokescreen-Role` |
| `denyMessage` | `""` | Text appended to the deny response |
| `metrics.enabled` | `true` | Prometheus metrics on 9810 |
| `extraArgs` | `[]` | More flags (`--timeout`, `--tls-server-bundle-file` with `extraVolumes`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/smokescreen \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

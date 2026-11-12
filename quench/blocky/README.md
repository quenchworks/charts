# Quenchworks Blocky

Hardened [Blocky](https://github.com/0xERR0R/blocky), a DNS proxy and ad blocker for the local
network: blocklists per client group, custom and conditional DNS, DNS-over-HTTPS/TLS upstreams,
caching and Prometheus metrics. The image is built from source, runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/blocky
kubectl run -it --rm q --image=ghcr.io/quenchworks/images/busybox:1.38.0 --restart=Never --command -- nslookup example.com dns-blocky
```

## Configuration

`config` is Blocky's own `config.yml` as YAML and goes to Blocky unchanged, except `ports`
(and `certFile` / `keyFile` with TLS), which the chart sets. The default forwards to Cloudflare
and Quad9 over DNS-over-HTTPS, caches for at least 5 minutes and serves metrics.

```yaml
config:
  blocking:
    denylists:
      ads: [https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts]
    clientGroupsBlock:
      default: [ads]
  conditional:
    mapping:
      corp.example: 10.0.0.53
```

| Key | Default | What it does |
|---|---|---|
| `config` | DoH upstreams, cache, metrics | Blocky's config.yml |
| `service.dnsPort` | `53` | DNS on UDP and TCP (container port 5353) |
| `tls.enabled` | `false` | DNS-over-TLS (853) and DNS-over-HTTPS (443, `/dns-query`) |
| `service.dotPort`, `service.dohPort` | `853`, `443` | Service ports for DoT and DoH |
| `extraArgs` | `[]` | More `blocky` arguments |

Port 4000 serves the API (`blocky query`, blocking on/off) and `/metrics`; keep it inside the
cluster.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/blocky \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

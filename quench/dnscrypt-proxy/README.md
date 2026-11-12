# Quenchworks dnscrypt-proxy

Hardened [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy): a DNS proxy that answers
plain DNS in the cluster and sends queries upstream over DNSCrypt v2, DNS-over-HTTPS or
Oblivious DoH, with filtering, cloaking (local overrides) and caching. It pairs with the Blocky
chart as an encrypted upstream. The image is built from source, runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install edns oci://ghcr.io/quenchworks/charts/dnscrypt-proxy
kubectl run -it --rm q --image=ghcr.io/quenchworks/images/busybox:1.38.0 --restart=Never --command -- nslookup example.com edns-dnscrypt-proxy
```

## Configuration

`config` is `dnscrypt-proxy.toml` written as YAML (the chart renders the TOML). It goes to
dnscrypt-proxy unchanged except `listen_addresses`, which the chart sets. The default uses
Cloudflare and Quad9 over DNS-over-HTTPS as static servers, so nothing is downloaded at start.
Rule files go in `files` and are mounted at `/etc/dnscrypt-proxy/<name>`:

```yaml
config:
  cloaking_rules: /etc/dnscrypt-proxy/cloaking.txt
  blocked_names:
    blocked_names_file: /etc/dnscrypt-proxy/blocked.txt
files:
  cloaking.txt: |
    printer.lan 10.0.0.20
  blocked.txt: |
    ads.example.com
```

| Key | Default | What it does |
|---|---|---|
| `config` | Cloudflare + Quad9 DoH, cache | dnscrypt-proxy.toml as YAML |
| `files` | `{}` | Rule files mounted next to the config |
| `service.dnsPort` | `53` | DNS on UDP and TCP (container port 5353) |
| `extraArgs` | `[]` | More `dnscrypt-proxy` arguments |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dnscrypt-proxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks Nebula

Hardened [Nebula](https://github.com/slackhq/nebula) lighthouse. Nebula is an overlay network:
hosts hold certificates from a shared CA and build mutually authenticated, encrypted tunnels to
each other, with per-host firewall rules. A lighthouse tells hosts where their peers are. This
chart runs one in the cluster without a TUN device, so it needs no NET_ADMIN. The image (with
`nebula-cert`) is built from source, runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest.

## Install

Nebula certificates are made with `nebula-cert`, not X.509 tooling, so the chart takes them from
a Secret. The image ships `nebula-cert`:

```bash
alias nebula-cert='docker run --rm -u $(id -u) -v "$PWD:/w" -w /w --entrypoint nebula-cert ghcr.io/quenchworks/images/nebula:1.12.0'
nebula-cert ca -name my-org
nebula-cert sign -name lighthouse -ip 192.168.100.1/24
kubectl create secret generic nebula-pki --from-file=ca.crt \
  --from-file=host.crt=lighthouse.crt --from-file=host.key=lighthouse.key
helm install mesh oci://ghcr.io/quenchworks/charts/nebula --set pki.existingSecret=nebula-pki \
  --set service.type=LoadBalancer
```

Keep `ca.key` offline; sign each host's certificate with it.

## Configuration

`config` is Nebula's own `config.yml` as YAML and goes to Nebula unchanged, except `pki`,
`listen`, `lighthouse.am_lighthouse` and `tun`, which the chart sets.

| Key | Default | What it does |
|---|---|---|
| `pki.existingSecret` | required | Secret with `ca.crt`, `host.crt`, `host.key` |
| `port` | `4242` | UDP listener |
| `config` | firewall: ICMP in, all out | Nebula's config.yml (firewall, relay, logging) |
| `config.relay.am_relay` | `false` | Relay traffic for hosts that cannot reach each other directly |
| `metrics.enabled` | `true` | Prometheus metrics on 8080; also the probes (UDP cannot be probed) |
| `service.type` | `ClusterIP` | `LoadBalancer` or `NodePort` for hosts outside the cluster |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nebula \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks bind

Hardened [ISC BIND 9](https://www.isc.org/bind/) (named), the authoritative
and recursive DNS server, on a nonroot 0-CVE image pinned by digest.

## Install

```sh
helm install dns oci://ghcr.io/quenchworks/charts/bind
```

The default `config` is a caching recursive resolver for private networks.
For an authoritative server, replace `config` and add zone files:

```yaml
config: |
  options {
      directory "/tmp";
      pid-file none;
      listen-on port 5353 { any; };
      recursion no;
      allow-query { any; };
  };
  zone "example.com" { type primary; file "/etc/named/zones/example.com.zone"; };
zones:
  example.com.zone: |
    $TTL 300
    @   IN SOA ns.example.com. admin.example.com. 1 3600 600 86400 300
    @   IN NS  ns.example.com.
    ns  IN A   192.0.2.1
    www IN A   192.0.2.80
```

named listens on 5353 inside the pod, since the pod runs nonroot. Keep
`listen-on port 5353` in your config; the Service publishes port 53 over UDP and
TCP. A change to `config` or `zones` rolls the pods, which is how named picks it
up (there is no rndc channel).

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/bind \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/bind --owner quenchworks`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `config` | caching resolver | named.conf, at `/etc/named/named.conf`. |
| `zones` | `{}` | Zone files by name, at `/etc/named/zones/<name>`. |
| `replicaCount` | `2` | Identical servers behind the Service. |
| `service.type`, `service.port` | `ClusterIP`, `53` | UDP and TCP. |

Zones are served from the ConfigMap, so every replica is a primary with the same
data. Dynamic updates and zone transfers to secondaries need a writable zone
directory: mount one with `extraVolumes` and point the zone `file` at it.

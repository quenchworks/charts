# Quenchworks bind

Hardened [ISC BIND 9](https://www.isc.org/bind/) (named), the authoritative
and recursive DNS server, on a nonroot CVE-gated image pinned by digest.

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
| `service.tlsPort` | `853` | DNS over TLS (pod 8853), only with `tls.enabled` |
| `tls.enabled` | `false` | DNS over TLS on 8853 beside plain DNS (cert at `/tls`); the chart adds the `tls` statement and a `listen-on port 8853 tls` line to `config`'s options block |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |

Zones are served from the ConfigMap, so every replica is a primary with the same
data. Dynamic updates and zone transfers to secondaries need a writable zone
directory: mount one with `extraVolumes` and point the zone `file` at it.

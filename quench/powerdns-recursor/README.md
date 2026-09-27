# Quenchworks PowerDNS Recursor

Hardened [PowerDNS Recursor](https://github.com/PowerDNS/pdns), the caching DNS
resolver, built from the release tarball, on a minimal, nonroot, 0-CVE image,
cosign-signed and pinned by digest. It runs as a stateless Deployment and
serves DNS on port 53, UDP and TCP.

## Install

```bash
helm install resolver oci://ghcr.io/quenchworks/charts/powerdns-recursor
```

Point clients at `resolver-powerdns-recursor:53`.

## Who may query

`allowFrom` lists the client ranges the recursor serves: private and CGN space
by default. Queries from anyone else are dropped without an answer. Never add
`0.0.0.0/0` on a public address; an open resolver gets used for amplification
attacks.

## Forward and local zones

Send a zone to specific servers instead of recursing, for example the
dns-stack's PowerDNS Authoritative. Forwarders are IP addresses, so use the
target Service's ClusterIP:

```yaml
forwardZones:
  - zone: k8s.internal
    forwarders: ['10.96.12.34:53']
```

Or answer a zone locally from zone-file text:

```yaml
authZones:
  corp.internal: |
    $ORIGIN corp.internal.
    @   300 IN SOA ns1 hostmaster 1 3600 600 86400 300
    www 300 IN A   10.0.0.10
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/powerdns-recursor \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/powerdns-recursor --owner quenchworks`.

## Values

| Key | Default | Description |
|---|---|---|
| `allowFrom` | private and CGN ranges | Clients served; everyone else is dropped |
| `dnssec` | `process` | off, process-no-validate, process, log-fail or validate |
| `forwardZones` | `[]` | `{zone, forwarders: [ip:port]}` entries |
| `authZones` | `{}` | Local zones, `{zone: zone-file text}` |
| `extraConfig` | `{}` | YAML merged into `recursor.yml` |
| `replicaCount` | `2` | Stateless replicas, each with its own cache |
| `autoscaling.enabled` | `false` | HPA on CPU |
| `service.port` | `53` | DNS port, UDP and TCP |

The common quench-common knobs (`nodeSelector`, `tolerations`, `extraVolumes`,
`sidecars`, probes and so on) are available as in every QuenchWorks chart.

# Unbound

[Unbound](https://nlnetlabs.nl/projects/unbound/) is a validating, recursive, caching
DNS resolver from NLnet Labs. This chart runs it on the QuenchWorks unbound image and
serves DNS on port 53 over UDP and TCP. The image is nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install unbound oci://ghcr.io/quenchworks/charts/unbound
```

## What the image configures

The image's own `unbound.conf` listens on 5053 (the Service maps 53 to it), validates
DNSSEC with the root trust anchors compiled into Unbound at that version, and answers
only clients in 127/8, 10/8, 172.16/12 and 192.168/16: an open resolver is a DDoS
amplifier. It reads `/etc/unbound/conf.d/*.conf`, which is where the chart's `config`
value lands.

## Your config

```yaml
config: |
  server:
    local-data: "db.internal. A 10.0.0.5"
    access-control: 100.64.0.0/10 allow
  forward-zone:
    name: "corp.example."
    forward-addr: 10.0.0.53
```

A config change rolls the pods.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `2` | resolver pods; each keeps its own cache |
| `config` | `""` | extra `unbound.conf` clauses |
| `service.port` | `53` | DNS port on the Service (UDP and TCP) |
| `service.clusterIP` | `""` | a fixed Service address |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind and requires a recursive answer, a
DNSSEC-authenticated answer (`ad`), SERVFAIL for a deliberately broken signature, and
the chart's `local-data` record.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

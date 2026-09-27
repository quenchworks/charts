# Quenchworks dns-stack

Self-hosted DNS for Kubernetes in one install:
[PowerDNS Authoritative](https://github.com/PowerDNS/pdns) serves the zones, and
[external-dns](https://github.com/kubernetes-sigs/external-dns) writes records
into it from annotated Services and Ingresses. All images are QuenchWorks
builds: nonroot, 0-CVE, pinned by digest and cosign-signed.

| Component | Chart | Name in the cluster |
|---|---|---|
| PowerDNS Authoritative 5.1.4 | powerdns 0.0.2 | `dns-powerdns` (DNS), `dns-powerdns-api` (API) |
| external-dns 0.23.0 | external-dns 0.0.7 | `dns-external-dns` |

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/dns-stack -n dns --create-namespace
```

The stack generates one PowerDNS API key (Secret `dns-stack-pdns-api`), which
both sides read. A post-install Job creates the zones in `zones` (default
`k8s.internal`), since external-dns only writes records inside existing zones.

## Publish a name

```bash
kubectl annotate service web external-dns.kubernetes.io/hostname=web.k8s.internal
```

Within a minute the record is served on port 53 of `dns-powerdns`. ClusterIP
Services get records too (`--publish-internal-services`). With `policy: sync`,
deleting the Service deletes its record; the ownership TXT record
(`external-dns/owner=dns-stack`) keeps that to records this stack created.

To make Pods resolve the zone, forward it to `dns-powerdns` from CoreDNS.

## Values

| Key | Default | Description |
|---|---|---|
| `zones` | `[k8s.internal]` | Zones the Job creates. Keep `external-dns.domainFilters` in sync |
| `powerdns.*` | see chart | Passed to the powerdns chart (`service.type`, `persistence`, ...) |
| `external-dns.*` | see chart | Passed to the external-dns chart (`sources`, `policy`, ...) |
| `zoneJob.image` | busybox 1.38.0 by digest | Image for the zone Job |

The external-dns 0.23 annotation prefix is `external-dns.kubernetes.io/`. For
resources still annotated with `external-dns.alpha.kubernetes.io/`, add
`--enable-legacy-annotation-prefix` to `external-dns.extraArgs`.

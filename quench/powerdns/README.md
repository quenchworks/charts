# Quenchworks PowerDNS

Hardened [PowerDNS Authoritative Server](https://github.com/PowerDNS/pdns),
built from the release tarball, on a minimal, nonroot, 0-CVE image,
cosign-signed and pinned by digest. It serves zones from LMDB on a persistent
volume and exposes the HTTP API for zone management.

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/powerdns
```

DNS is served on port 53, UDP and TCP, from the `dns-powerdns` Service. For a
public authoritative server, set `service.type=LoadBalancer`.

## Manage zones

The HTTP API is on `dns-powerdns-api:8081`. The chart generates the API key on
install and keeps it on upgrade:

```bash
KEY=$(kubectl get secret dns-powerdns -o jsonpath='{.data.api-key}' | base64 -d)
kubectl port-forward svc/dns-powerdns-api 8081 &
curl -H "X-API-Key: $KEY" -X POST http://127.0.0.1:8081/api/v1/servers/localhost/zones \
  -d '{"name": "example.com.", "kind": "Native", "nameservers": ["ns1.example.com."]}'
```

[external-dns](https://github.com/kubernetes-sigs/external-dns) can manage
records through the same API with `--provider=pdns`. If it runs in another
namespace, add that namespace to `networkPolicy.apiAllowNamespaces`.

## Storage and replicas

Zones and DNSSEC keys live in LMDB, which needs no schema and is created on first
start. The chart runs one replica, because two servers cannot share an LMDB file.
For more servers, run secondaries that transfer zones from this one, or point
the server at a shared SQL backend with `extraConfig` (`gpgsql`, `gmysql` and
`gsqlite3` are compiled in; their schema has to be loaded first).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/powerdns \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/powerdns --owner quenchworks`.

## Values

| Key | Default | Description |
|---|---|---|
| `api.enabled` | `true` | HTTP API and webserver on 8081 |
| `api.key` | `""` | API key; generated and kept when empty |
| `api.existingSecret` | `""` | Secret holding the key instead |
| `api.existingSecretKey` | `api-key` | Key in that Secret |
| `api.allowFrom` | `0.0.0.0/0, ::/0` | Sources the webserver answers |
| `persistence.enabled` | `true` | PVC for LMDB; an emptyDir loses zones on restart |
| `persistence.size` | `1Gi` | PVC size |
| `extraConfig` | `""` | Raw `pdns.conf` lines appended to the generated config |
| `service.type` | `ClusterIP` | DNS Service type |
| `service.port` | `53` | DNS port, UDP and TCP |
| `service.apiPort` | `8081` | API Service port |
| `networkPolicy.apiAllowNamespaces` | `[]` | Extra namespaces allowed to reach the API |

The common quench-common knobs (`nodeSelector`, `tolerations`, `extraVolumes`,
`sidecars`, probes and so on) are available as in every QuenchWorks chart.

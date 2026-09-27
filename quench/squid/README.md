# Quenchworks Squid

Hardened [Squid](https://github.com/squid-cache/squid), the caching forward
proxy for HTTP and HTTPS (CONNECT), on a minimal, nonroot, 0-CVE image,
cosign-signed and pinned by digest. It runs as a stateless Deployment on a
read-only rootfs, listens on port `3128`, and caches in memory only.

## Install

```bash
helm install egress oci://ghcr.io/quenchworks/charts/squid
```

Point clients at the Service:

```bash
export HTTP_PROXY=http://egress-squid.default.svc.cluster.local:3128
export HTTPS_PROXY=$HTTP_PROXY
```

Every request shows up in `kubectl logs deploy/egress-squid` with its cache
result (`TCP_MISS/200`, `TCP_HIT/200`, `TCP_DENIED/403`).

## Access policy

The generated `squid.conf` allows clients from `allowedSources` (RFC 1918 and
CGN space by default) and denies everyone else with 403. CONNECT is allowed only
to `sslPorts` (443), and plain requests only to `safePorts`, so the proxy is not
an open relay. Requests to loopback and link-local destinations are refused.

The probes GET `/squid-internal-static/icons/SN.png`, which squid serves from
memory. The kubelet sends them from the node IP, so keep the node CIDR in
`allowedSources` if you narrow it.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/squid \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/squid --owner quenchworks`.

## Values

| Key | Default | Description |
|---|---|---|
| `allowedSources` | RFC 1918 + CGN + ULA | Client CIDRs allowed to use the proxy |
| `sslPorts` | `[443]` | Ports CONNECT may tunnel to |
| `safePorts` | `80, 21, 443, 1025-65535` | Ports plain requests may reach |
| `cacheMem` | `64 MB` | In-memory object cache |
| `extraConfig` | `""` | Lines added before the final `http_access deny all` |
| `config.raw` | `""` | A complete `squid.conf` that replaces the generated one |
| `config.existingConfigMap` | `""` | ConfigMap with a `squid.conf` key |
| `replicaCount` | `1` | Replicas; each keeps its own cache |
| `service.port` | `3128` | Service port |
| `networkPolicy.enabled` | `true` | Ingress policy on the proxy port; egress is open |
| `networkPolicy.allowExternal` | `true` | Allow clients from other namespaces |
| `podDisruptionBudget.enabled` | `true` | PDB with `minAvailable: 1` |
| `autoscaling.enabled` | `false` | HPA on CPU |

The common quench-common knobs (`nodeSelector`, `tolerations`, `extraVolumes`,
`sidecars`, probes and so on) are available as in every QuenchWorks chart.

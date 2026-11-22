# Quenchworks ZAP

Hardened [OWASP ZAP](https://www.zaproxy.org) as an API daemon: spider, passive and active scans, alerts and
reports driven over its REST API from CI pipelines or other tools. The image packages the upstream 2.17.0
distribution on the Wolfi Java 21 runtime with log4j swapped to 2.26.1, runs as uid 1001 on a read-only root
filesystem, and is CVE-gated at build, cosign-signed and pinned by digest. commons-httpclient 3.1's CVE-2012-5783
is VEXed: the bundled network add-on replaces that sender when ZAP starts.

The chart generates the API key once, keeps ZAP's home (config, its root CA, sessions) on a volume, and registers
the Service's DNS names as ZAP aliases. ZAP answers as its API only when a request is addressed to itself; any other
Host header is proxied, so an Ingress host has to be added to `extraAliases`.

## Install

```bash
helm install zap oci://ghcr.io/quenchworks/charts/zap -n zap --create-namespace
```

Read the key from the chart Secret (see the install notes) and call the API with `apikey=<key>` or the
`X-ZAP-API-Key` header. Only scan systems you are authorized to test.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `api.key` | `""` | Generated when empty |
| `api.allowedAddresses` | `.*` | Client addresses allowed to call the API (regex) |
| `extraAliases` | `[]` | More host names ZAP answers as its API (an Ingress host) |
| `extraConfig` | `[]` | More `-config key=value` settings |
| `javaOpts` | `""` | JVM options, e.g. `-Xmx2g` |
| `persistence.enabled` | `true` | ZAP's home on a PVC |

ZAP runs one replica (its home on one volume), replaced with the Recreate strategy.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/zap \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

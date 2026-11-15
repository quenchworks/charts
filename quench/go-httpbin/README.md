# Quenchworks go-httpbin

Hardened [go-httpbin](https://github.com/mccutchen/go-httpbin), httpbin in one Go binary: an HTTP
request and response test service with echo, status-code, delay, redirect, auth, cookie and streaming
endpoints, for testing proxies, gateways, ingress controllers and HTTP clients. The image is built from
source (pure Go, no module dependencies); it runs as uid 1001 and is CVE-gated at build, cosign-signed
and pinned by digest.

## Install

```bash
helm install httpbin oci://ghcr.io/quenchworks/charts/go-httpbin
kubectl port-forward svc/httpbin-go-httpbin 8080:8080
curl http://127.0.0.1:8080/get
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `replicaCount` | `2` | Stateless replicas |
| `maxBodySize` | `0` | Largest accepted body in bytes (0: upstream's 1 MiB) |
| `maxDuration` | `""` | Longest `/delay` or `/drip` (empty: upstream's 10s) |
| `allowedRedirectDomains` | `[]` | Hosts `/redirect-to` may send clients to (empty: any) |
| `fullVersion` | `false` | Show the version on `/version` |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/go-httpbin \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

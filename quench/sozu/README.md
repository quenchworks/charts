# Quenchworks Sozu

Hardened [Sozu](https://github.com/sozu-proxy/sozu), the HTTP/HTTPS reverse proxy in Rust that is
reconfigured at runtime over its command socket and upgrades without dropping connections. The
image is built from source with cargo auditable, runs as uid 1001 and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install sozu oci://ghcr.io/quenchworks/charts/sozu -f my-values.yaml
```

## Routes

Routes are Sozu `[clusters]` TOML in the `clusters` value. Backends take `host:port`, so a
Kubernetes Service name works; Sozu resolves it when it loads the config.

```yaml
clusters: |
  [clusters.app]
  protocol = "http"
  frontends = [
    { address = "0.0.0.0:8080", hostname = "app.example.com" },
    { address = "0.0.0.0:8443", hostname = "app.example.com", certificate = "/tls/tls.crt", key = "/tls/tls.key" },
  ]
  backends = [ { address = "app.default.svc.cluster.local:80", backend_id = "app-0" } ]
```

A request whose Host matches no frontend gets a 404. Changing `clusters` rolls the pods. Routes
added at runtime with the CLI (`kubectl exec deploy/sozu -- sozu -c /etc/sozu/config.toml
frontend http add ...`) apply to that pod only and are lost when it restarts.

## TLS

`tls.enabled: true` mounts a certificate at `/tls` (`tls.crt`, `tls.key`, `ca.crt`) from
`tls.existingSecret`, a cert-manager Certificate, or a Helm-generated self-signed CA. Reference
those files from HTTPS frontends. Sozu picks the certificate by SNI, so the certificate must
name the frontend's hostname: add it with `tls.certManager.dnsNames` (also used by the
self-signed certificate).

## Ports

| Port | Listener |
|---|---|
| 8080 | HTTP (`listeners.http.port`) |
| 8443 | HTTPS (`listeners.https.port`, `listeners.https.enabled`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/sozu \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

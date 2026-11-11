# Quenchworks mitmproxy

Hardened [mitmproxy](https://github.com/mitmproxy/mitmproxy), the interactive TLS-intercepting
HTTP proxy for debugging and testing, with its mitmweb UI, on a minimal, nonroot, CVE-gated
image, cosign-signed and pinned by digest. The image rebuilds mitmproxy's native parts from
source (the Rust extension with cargo auditable, aioquic against Wolfi's OpenSSL) so nothing in
it is hidden from the scanner.

## Install

```bash
helm install mitm oci://ghcr.io/quenchworks/charts/mitmproxy
```

Point a client at it and trust its CA:

```bash
kubectl exec deploy/mitm-mitmproxy -- /opt/mitmproxy/venv/bin/python \
  -c "print(open('/home/mitmproxy/.mitmproxy/mitmproxy-ca-cert.pem').read())" > mitm-ca.pem
kubectl port-forward svc/mitm-mitmproxy 8080 &
curl --cacert mitm-ca.pem -x http://127.0.0.1:8080 https://example.com/
```

## The UI

`ui.enabled` (default) runs mitmweb: the flows, replay and edit UI on `ui.port` (8081),
behind a password generated into the `<release>-mitmproxy-web` Secret on first install and
kept across upgrades (or `ui.password`, or `ui.existingSecret` with key `password`):

```bash
kubectl port-forward svc/mitm-mitmproxy 8081
kubectl get secret mitm-mitmproxy-web -o jsonpath='{.data.password}' | base64 -d
```

With `ui.enabled=false` the pod runs mitmdump (headless).

## Modes and options

`modes` is a list of mitmproxy `--mode` values; each listens on its own port, and the first is
the Service's `proxy` port. `options` passes extra `--set key=value` options:

```yaml
modes:
  - regular@8080
  - socks5@1080
  - reverse:https://api.internal@8443
options:
  ssl_insecure: "true"      # do not verify upstream certificates
  block_global: "false"
```

## A stable CA

By default the CA is generated at every pod start, so clients must re-trust it after a
restart. To keep one CA, create a Secret with key `mitmproxy-ca.pem` (the CA private key and
certificate in one PEM, as mitmproxy writes it) and set `ca.existingSecret`. A busybox init
container copies it into mitmproxy's writable config directory.

## Not included

Local capture mode (intercepting processes on the node) needs root and BPF, which a nonroot
pod does not have; its redirector binary is not in the image. The proxy listener is plain
HTTP (CONNECT) by design: TLS is what mitmproxy intercepts.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mitmproxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

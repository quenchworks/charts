# Quenchworks GOST

Hardened [GOST](https://github.com/go-gost/gost) (GO Simple Tunnel): a multi-protocol forward
proxy and tunnel. The chart runs an authenticated HTTP proxy out of the box, and any other GOST
service (SOCKS5, relay, port forwarding, Shadowsocks, over TCP, TLS, QUIC or WebSocket) can be
added in `extraServices`.

The image is built from the upstream release tag as one static Go binary, runs as nonroot uid
1001, is CVE-gated (the build fails on any fixable CVE), and is cosign-signed and pinned by digest.

## Install

```bash
helm install egress oci://ghcr.io/quenchworks/charts/gost
kubectl get secret egress-gost -o jsonpath='{.data.password}' | base64 -d; echo
# pods use it as http://gost:<password>@egress-gost:8080
```

A SOCKS5 proxy next to it:

```yaml
extraServices:
  - name: socks
    addr: ":1080"
    handler: { type: socks5 }
    listener: { type: tcp }
extraPorts:
  - { name: socks, port: 1080, protocol: TCP }
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/gost \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/gost@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/gost` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `1` | Stateless; scale freely. |
| `proxy.enabled` / `port` / `type` | `true` / `8080` / `http` | The built-in proxy (`http` or `socks5`). |
| `proxy.auth.username` / `password` | `gost` / `""` | Proxy credentials; an empty password is generated and kept across upgrades. |
| `extraServices` | `[]` | More GOST services (entries of the config's `services` list). |
| `extraPorts` | `[]` | Ports for `extraServices` (`{name, port, protocol}`). |
| `metrics.port` | `9000` | Prometheus `/metrics`, also the probes' target. |
| `tls.enabled` | `false` | Make the built-in proxy an HTTPS proxy with the chart's certificate. |
| `service.type` | `ClusterIP` | |
| `networkPolicy.enabled` / `allowExternal` | `true` / `true` | Ingress to every GOST port. |
| `resources` | 50m / 64Mi requests, 1 CPU / 256Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **The config is a Secret.** `gost.yaml` carries the proxy password, so it is rendered into the
  chart's Secret, not a ConfigMap; a values change rolls the pods.
- **Probes** read `/metrics` on the metrics service.
- **TLS** wraps the built-in proxy listener (`type: tls`), so clients connect with
  `--proxy https://...` and verify the chart's CA.

GOST is MIT licensed.

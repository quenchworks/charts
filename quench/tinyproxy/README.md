# Quenchworks Tinyproxy

Hardened [Tinyproxy](https://github.com/tinyproxy/tinyproxy): a small HTTP and HTTPS (CONNECT) forward proxy with
client ACLs, URL and domain filtering, and upstream chaining. The image is C built from source, runs as uid 1001 on a
read-only rootfs with no shell, and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install egress oci://ghcr.io/quenchworks/charts/tinyproxy
```

Then point clients at it: `HTTPS_PROXY=http://egress-tinyproxy.<namespace>:8888`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `config` | see values.yaml | The whole `tinyproxy.conf`. Allow lines are the client ACL (loopback and the private ranges by default); ConnectPort limits CONNECT to 443 and 563. `Port` must stay 8888 |
| `replicaCount` | `1` | Tinyproxy is stateless; raise it behind the Service |
| `service.port` | `8888` | The proxy port clients use |
| `networkPolicy.enabled` | `true` | Ingress allowed on 8888 only |

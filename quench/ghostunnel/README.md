# Quenchworks ghostunnel

Hardened [ghostunnel](https://github.com/ghostunnel/ghostunnel), a TLS proxy with mutual
authentication. This chart runs it in server mode: it accepts mTLS on its listener, checks the
client certificate against a client CA and an allow list, and forwards accepted connections to
a plaintext service. The image is built from source with PKCS#11 support, runs as uid 1001 and
is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install pg-mtls oci://ghcr.io/quenchworks/charts/ghostunnel --set target=postgres:5432
```

Clients verify the server with `ca.crt` from the Secret `pg-mtls-ghostunnel-tls`. Unless you
bring your own client CA, the chart also generates one plus a client certificate
(CN `pg-mtls-ghostunnel-client`) in the Secret `pg-mtls-ghostunnel-client`; mount it in the
client. A plaintext client can run ghostunnel in client mode next to it:

```bash
ghostunnel client --listen localhost:5432 --target pg-mtls-ghostunnel:8443 \
  --cert tls.crt --key tls.key --cacert server-ca.crt
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `target` | required | Plaintext backend, `host:port` |
| `port` | `8443` | mTLS listener |
| `allow.all` | `false` | Accept any certificate the client CA signed |
| `allow.cns`, `allow.ous`, `allow.dnsNames`, `allow.uris` | `[]` | Allow lists (CN, OU, DNS SAN, URI SAN such as SPIFFE IDs) |
| `clientCA.existingSecret` | `""` | Secret with `ca.crt` for client certificates; empty generates one |
| `status.enabled`, `status.port` | `true`, `6060` | Plain-HTTP `/_status` and `/_metrics` |
| `tls.existingSecret`, `tls.certManager` | self-signed | Server certificate source; TLS is always on |
| `extraArgs` | `[]` | More `ghostunnel server` flags (`--timed-reload`, `--proxy-protocol`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ghostunnel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

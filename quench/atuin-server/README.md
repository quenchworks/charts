# Quenchworks Atuin server

Hardened [Atuin](https://atuin.sh) sync server: your shell history, end-to-end encrypted on the
client, synced across machines through a server you run. The image is built from source with cargo
auditable (so scanners see every crate) against Wolfi OpenSSL; it runs as uid 1001 and is CVE-gated
at build, cosign-signed and pinned by digest.

## Install

```bash
helm install atuin oci://ghcr.io/quenchworks/charts/atuin-server
kubectl get secret atuin-atuin-server -o jsonpath='{.data.password}' | base64 -d   # user admin
```

The server has no TLS listener: expose it through an ingress or gateway with TLS, set
`sync_address = "https://atuin.example.com"` in the client's `config.toml`, then `atuin login -u admin`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username`, `admin.email` | `admin`, `admin@example.com` | The account the chart creates and keeps in step with the Secret |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `openRegistration` | `false` | Let anyone register (`atuin register`) |
| `maxRecordSize` | `1GiB` | Largest record a client may upload |
| `settings` | `{}` | More `ATUIN_*` variables (metrics, PostgreSQL `ATUIN_DB_URI`) |
| `persistence.size` | `5Gi` | server.toml and the SQLite database |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/atuin-server \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

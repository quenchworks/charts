# Quenchworks sigstore-stack

Self-hosted [Sigstore](https://www.sigstore.dev): keyless signing with cosign
against your own certificate authority, transparency log and timestamp
authority instead of the public-good instance. One install runs:

| Component | Chart | Address |
|---|---|---|
| Fulcio, the certificate authority | `fulcio` | `http://sigstore-fulcio:8080` |
| Rekor v2, the transparency log | `rekor-tiles` | write `http://sigstore-rekor:3000`, read `:8080` |
| Timestamp Authority (RFC 3161) | `timestamp-authority` | `http://sigstore-tsa:3000/api/v1/timestamp` |

Every image is nonroot, 0 fixable CVEs, pinned by digest and cosign-signed.

## Install

```bash
helm install sigstore oci://ghcr.io/quenchworks/charts/sigstore-stack \
  --set rekor-tiles.hostname=rekor.example.com
```

Names are fixed, so run one stack per namespace.

## Before real use

The defaults boot with no secrets and are for testing: Fulcio's ephemeral CA
and the TSA's in-memory signer both change on every restart, which breaks every
signature made before it. For a lasting deployment:

- `fulcio.ca.type=fileca` with `fulcio.ca.file.existingSecret` (CA certificate,
  encrypted key, password).
- `fulcio.config.oidc-issuers`: the identity providers you trust.
- `timestamp-authority.signer.type=file` with a key and certificate chain in a
  Secret.
- `rekor-tiles.hostname` set once, before the first entry. Its checkpoint key is
  generated and kept across upgrades; supply your own with
  `rekor-tiles.signer.existingSecret`.

Clients then trust this instance through a trusted root built from the Fulcio
trust bundle, the Rekor log key (printed at start) and the TSA chain.

## Values

| Key | Default | Notes |
|---|---|---|
| `fulcio.enabled` | `true` | any subchart value goes under `fulcio.` |
| `rekor-tiles.enabled` | `true` | any subchart value goes under `rekor-tiles.` |
| `timestamp-authority.enabled` | `true` | any subchart value goes under `timestamp-authority.` |

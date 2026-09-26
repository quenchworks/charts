# Quenchworks Sigstore Fulcio

[Fulcio](https://github.com/sigstore/fulcio) is the Sigstore certificate
authority: it exchanges an OIDC identity token for a short-lived code-signing
certificate, which makes keyless signing with cosign possible. The image is
nonroot, 0 fixable CVEs, pinned by digest and cosign-signed.

## Install

```bash
helm install fulcio oci://ghcr.io/quenchworks/charts/fulcio
```

The default `ephemeralca` is for testing: it makes a new root on every start.
For real use, create a Secret with a PEM CA certificate, its encrypted private
key and the key password, then:

```bash
helm install fulcio oci://ghcr.io/quenchworks/charts/fulcio \
  --set ca.type=fileca --set ca.file.existingSecret=fulcio-ca
```

KMS, Tink and Google CA Service backends take their settings through
`extraArgs`. PKCS#11 needs cgo and is not in this image.

## Values

| Key | Default | Notes |
|---|---|---|
| `ca.type` | `ephemeralca` | `ephemeralca`, `fileca`, `kmsca`, `tinkca`, `googleca` |
| `ca.file.existingSecret` | `""` | Secret with `cert.pem`, `key.pem`, `password` |
| `ctLogUrl` | `""` | CT log URL; empty turns Certificate Transparency off |
| `config` | public Sigstore issuer | Fulcio `config.yaml`: the OIDC issuers it trusts |

Clients: `cosign sign --fulcio-url http://<service>:8080`.

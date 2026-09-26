# Quenchworks Sigstore Timestamp Authority

The [Sigstore Timestamp Authority](https://github.com/sigstore/timestamp-authority)
issues RFC 3161 timestamps: it countersigns an artifact hash with the current
time, so a signature can be shown to predate a key's expiry or revocation. The
image is nonroot, 0 fixable CVEs, pinned by digest and cosign-signed.

## Install

```bash
helm install tsa oci://ghcr.io/quenchworks/charts/timestamp-authority
```

The default `memory` signer is for testing: it makes a new key on every start.
For real use, create a Secret with a PEM private key, its certificate chain and
the key password, then:

```bash
helm install tsa oci://ghcr.io/quenchworks/charts/timestamp-authority \
  --set signer.type=file --set signer.file.existingSecret=tsa-signer
```

The chain must be a timestamping chain (the leaf carries the
`id-kp-timeStamping` extended key usage). KMS and Tink signers take their
settings through `extraArgs`.

## Values

| Key | Default | Notes |
|---|---|---|
| `signer.type` | `memory` | `memory`, `file`, `kms`, `tink` |
| `signer.file.existingSecret` | `""` | Secret with `key.pem`, `chain.pem`, `password` |
| `ntpMonitoring` | `true` | refuse to sign when the clock drifts; needs outbound UDP 123 |
| `replicaCount` | `1` | scale only with a shared signer (not `memory`) |

Clients: `cosign sign --timestamp-server-url http://<service>:3000/api/v1/timestamp`.

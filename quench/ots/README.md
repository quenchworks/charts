# OTS

[OTS](https://github.com/Luzifer/ots), one-time secret sharing: the browser encrypts the secret (AES-256), the server
keeps only the ciphertext, and the link self-destructs after one read. The image is built from source by QuenchWorks,
CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install ots oci://ghcr.io/quenchworks/charts/ots --set valkey.enabled=true --set tls.enabled=true
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `secretExpiry` | `604800` | Longest a secret may live, in seconds (0: no cap). |
| `valkey.enabled` | `false` | Secrets in the bundled Valkey (survive restarts, scale out). Off: in memory, one replica. |
| `externalRedis.existingSecret` | `""` | A Secret holding an external Redis URL (key `externalRedis.existingSecretUrlKey`). |
| `replicaCount` | `1` | Replicas when a Redis holds the secrets. |
| `tls.enabled` | `false` | OTS serves HTTPS on 3000 (existing Secret, cert-manager, or a Helm-made CA). |

Browsers need HTTPS for the client-side encryption (Web Crypto): enable TLS here or on an Ingress.

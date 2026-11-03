# Quenchworks tika

Hardened [Apache Tika](https://tika.apache.org) server on a minimal, nonroot,
0-CVE image, built from the official release and pinned by digest.

It extracts text and metadata from PDF, Office, HTML and many other formats
over a REST API on port 9998.

## Install

```sh
helm install tika oci://ghcr.io/quenchworks/charts/tika
```

Extract text and metadata from a document:

```sh
kubectl port-forward svc/tika 9998:9998 &
curl -T report.pdf -H 'Accept: text/plain' http://127.0.0.1:9998/tika
curl -T report.pdf -H 'Accept: application/json' http://127.0.0.1:9998/meta
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/tika \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/tika --owner quenchworks`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `javaOpts` | `-XX:MaxRAMPercentage=40` | `JAVA_TOOL_OPTIONS`; also reaches the forked parser JVMs. |
| `extraArgs` | `[]` | Appended to the server command line. |
| `resources` | 200m / 1Gi, limit 3Gi | Large documents need more memory. |
| `service.type`, `service.port` | `ClusterIP`, `9998` | The REST Service. |
| `tls.enabled` | `false` | the port serves HTTPS only (Tika 4 `server.tlsConfig`, BETA upstream; PKCS12 from an openssl init container); probes move to HTTPS |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |
| `openssl.digest` | (pinned) | init container that builds the PKCS12 keystore |
| `networkPolicy.enabled` | `false` | Ingress only on the REST port. |

The root filesystem is read-only; Tika writes its temp files to a `/tmp` emptyDir.

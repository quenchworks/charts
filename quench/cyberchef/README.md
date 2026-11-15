# Quenchworks CyberChef

Hardened [CyberChef](https://github.com/gchq/CyberChef), GCHQ's web app for encoding, decoding,
encryption, compression and data analysis. Everything runs in the browser; the server only serves
static files. The image is built from source with Node 24 and served by Wolfi nginx; it runs as uid
1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install chef oci://ghcr.io/quenchworks/charts/cyberchef
kubectl port-forward svc/chef-cyberchef 8080:8080   # open http://127.0.0.1:8080/
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `replicaCount` | `2` | Stateless replicas |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

The usual production knobs (resources, probes, network policy, PDB, scheduling) are in `values.yaml`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cyberchef \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

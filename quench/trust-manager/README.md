# Quenchworks trust-manager

Hardened [trust-manager](https://github.com/cert-manager/trust-manager), cert-manager's trust
bundle distributor. A `Bundle` gathers CA certificates from ConfigMaps, Secrets and inline
PEM in the trust namespace and writes the combined bundle into a ConfigMap (or Secret) in
every selected namespace, and keeps it current as the sources change. The image is minimal,
runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped, ships
0-CVE, is cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest.

The chart needs no cert-manager: Helm generates the validating webhook's CA and serving
certificate on first install and reuses them on upgrade.

## Install

```bash
helm install trust-manager oci://ghcr.io/quenchworks/charts/trust-manager -n cert-manager --create-namespace
```

The trust namespace is the release namespace: put source ConfigMaps and Secrets there.

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: my-ca
spec:
  sources:
    - configMap: {name: my-ca-source, key: ca.crt}
  target:
    configMap: {key: ca-bundle.crt}
    # namespaceSelector: {matchLabels: {trust: enabled}}
```

The upstream default package (the public CA set as a source, `useDefaultCAs`) is not
shipped; bundles name their own sources.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/trust-manager \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/trust-manager --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `crds.enabled` / `crds.keep` | `true` / `true` | The Bundle CRD; kept on uninstall. |
| `secretTargets.enabled` | `false` | Allows Secret targets; grants Secret writes cluster-wide. |
| `filterExpiredCertificates` | `true` | Drop expired certificates from bundles. |
| `replicaCount` | `1` | Above 1 turns on leader election. |
| `webhook.timeoutSeconds` | `5` | |
| `logLevel` / `logFormat` | `1` / `text` | |
| `extraArgs` | `[]` | Any other trust-manager flag. |

The common pod knobs from quench-common work as in every Quenchworks chart.

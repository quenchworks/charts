# Quenchworks Connaisseur

Hardened [Connaisseur](https://github.com/sse-secure-systems/connaisseur), the
Kubernetes admission controller that verifies container image signatures before
workloads are admitted. Validators hold your trust roots (Cosign/Sigstore keys or
keyless identities, Notary v1, Notary v2, or a static allow/deny), and the policy
maps image patterns to validators. The chart runs Connaisseur as a Deployment
behind a mutating admission webhook for Pods and every workload controller. Helm
generates the webhook's CA and serving certificate and keeps them on upgrade, so
cert-manager is not needed. The image is minimal, runs nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, ships 0-CVE, is
cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install connaisseur oci://ghcr.io/quenchworks/charts/connaisseur \
  --namespace connaisseur --create-namespace
```

The default policy admits every image, so the install blocks nothing. To enforce
signatures, add a validator and point the policy at it:

```yaml
validators:
  - {name: allow, type: static, approve: true}
  - name: ours
    type: cosign
    trustRoots:
      - name: default
        key: |
          -----BEGIN PUBLIC KEY-----
          ...
          -----END PUBLIC KEY-----
policy:
  - {pattern: "*:*", validator: ours}
  - {pattern: "registry.k8s.io/*:*", validator: allow}
```

The release namespace and `kube-system` are never checked (`webhook.excludeNamespaces`
adds more). With `webhook.failurePolicy: Fail` (the default) workloads are rejected
while Connaisseur is unreachable; `Ignore` admits them unchecked instead.

The signature cache is off (`cacheExpirySeconds: 0`); a cache above 0 needs a Redis,
which this chart does not run.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/connaisseur \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/connaisseur --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `validators` | static `allow` and `deny` | Trust roots, written to `/app/config/config.yaml`. |
| `policy` | `*:*` to `allow` | Image patterns to validators; the most specific pattern wins. |
| `alerting` | `{}` | Notification config, `/app/alerts/config.yaml`. |
| `webhook.failurePolicy` | `Fail` | `Ignore` admits workloads when the webhook is down. |
| `webhook.excludeNamespaces` | `[kube-system]` | The release namespace is always excluded. |
| `cacheExpirySeconds` | `0` | Above 0 needs a Redis. |
| `logLevel` | `info` | |
| `rbac.clusterRules` | get/list on workload kinds | For automatic child approval. |
| `replicaCount` | `1` | Stateless. |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides,
security contexts) work as in every Quenchworks chart.

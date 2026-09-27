# Quenchworks supply-chain-stack

Supply-chain control at admission time, from QuenchWorks images (nonroot, 0
fixable CVEs, pinned by digest, cosign-signed):

| Component | Chart | Role |
|---|---|---|
| Kyverno | `kyverno` | admission policies |
| trivy-operator | `trivy-operator` | scans running workloads, writes VulnerabilityReports |
| `quench-signed-images` | this stack | the ClusterPolicy below |

## The policy

In each namespace labelled `quench-works.com/verify-images=true`:

1. Pods may only run images from `ghcr.io/quenchworks/images/*`
   (`verifyImages.allowedImages`).
2. Every QuenchWorks image must carry a cosign keyless signature made by a
   workflow of the `quenchworks/images` repository on `main`, issued through
   GitHub Actions OIDC and logged in Sigstore's public Rekor. Kyverno checks it
   on admission and rewrites the image to its digest.

Namespaces without the label are not affected, so the stack can go into an
existing cluster without breaking system workloads.

## Install

```bash
helm install supply-chain oci://ghcr.io/quenchworks/charts/supply-chain-stack -n supply-chain --create-namespace
kubectl label namespace my-app quench-works.com/verify-images=true
```

## Values

| Key | Default | Notes |
|---|---|---|
| `verifyImages.namespaceLabel` | `quench-works.com/verify-images` | the opt-in label |
| `verifyImages.allowedImages` | `ghcr.io/quenchworks/images/*` | add your own registries here |
| `verifyImages.subjectRegExp` | QuenchWorks images workflows on main | the signer identity |
| `verifyImages.rekorUrl` | `https://rekor.sigstore.dev` | the transparency log checked |
| `verifyImages.webhookTimeoutSeconds` | `30` | signature checks fetch over the network |

## Notes

- Signature checks need egress to `ghcr.io` and to Sigstore (`rekor.sigstore.dev`,
  `tuf-repo-cdn.sigstore.dev`). In an air-gapped cluster, point the policy at
  your own Sigstore (see the QuenchWorks `sigstore-stack`).
- Images you add to `allowedImages` from other registries are allowed but not
  signature-checked; add a verifyImages rule for them if they are signed.
- The policy is applied by a post-install Job once Kyverno's webhook answers,
  so `helm uninstall` leaves the `quench-signed-images` ClusterPolicy behind;
  delete it by hand.

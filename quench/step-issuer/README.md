# Quenchworks step-issuer

Hardened [step-issuer](https://github.com/smallstep/step-issuer), smallstep's cert-manager
external issuer. `StepIssuer` and `StepClusterIssuer` resources sign cert-manager
CertificateRequests through a [step-ca](https://smallstep.com/docs/step-ca/) JWK
provisioner, so certificates for in-cluster services come from your own CA. The image is
minimal, runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped, ships 0-CVE, is cosign-signed (keyless / Sigstore), and the chart pins it by the
signed digest.

## Install

Needs cert-manager. The approver binding lets cert-manager's controller approve requests
for Step issuers; point it at your cert-manager controller's ServiceAccount:

```bash
helm install step-issuer oci://ghcr.io/quenchworks/charts/step-issuer -n pki \
  --set approver.certManagerServiceAccount.name=cert-manager-controller \
  --set approver.certManagerServiceAccount.namespace=cert-manager
```

Then a cluster issuer for a step-ca (the QuenchWorks step-ca chart serves its root at
`/roots.pem` and its provisioners, with their `kid`, at `/provisioners`):

```yaml
apiVersion: certmanager.step.sm/v1beta1
kind: StepClusterIssuer
metadata:
  name: step-ca
spec:
  url: https://ca-step-ca.pki.svc
  caBundle: <base64 of the root certificate PEM>
  provisioner:
    name: admin@quench-works.com
    kid: <kid>
    passwordRef: {name: ca-step-ca, namespace: pki, key: provisioner-password}
```

A Certificate uses it with `issuerRef: {group: certmanager.step.sm, kind:
StepClusterIssuer, name: step-ca}`. The pki-stack chart wires all of this for you.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/step-issuer \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|---|---|---|
| `crds.enabled` / `crds.keep` | `true` / `true` | StepIssuer + StepClusterIssuer CRDs; kept on uninstall. |
| `approver.enabled` | `true` | Binds the signer-approve ClusterRole to cert-manager's controller. |
| `approver.certManagerServiceAccount.name` / `.namespace` | `cert-manager-controller` / `cert-manager` | |
| `replicaCount` | `1` | Above 1 turns on leader election. |
| `extraArgs` | `[]` | e.g. `--disable-approval-check`. |

RBAC follows upstream: read Secrets cluster-wide (a StepIssuer's provisioner password lives
in its own namespace) and update CertificateRequests.

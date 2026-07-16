# Quenchworks cert-manager

Hardened [cert-manager](https://github.com/cert-manager/cert-manager) on minimal,
nonroot, 0-CVE images, pinned by digest. cert-manager automates the issuance and
renewal of X.509 certificates in Kubernetes from ACME (Let's Encrypt), SelfSigned,
CA, Vault and other Issuers, driven by the `Certificate` / `Issuer` /
`ClusterIssuer` CRDs.

## Install

```sh
helm install cert-manager oci://ghcr.io/quenchworks/charts/cert-manager \
  -n cert-manager --create-namespace
```

## Architecture

cert-manager ships four binaries. This chart runs three Deployments (each with its
own ServiceAccount and minimal RBAC) and hands the fourth image to the controller:

| Deployment | Image | Role |
|------------|-------|------|
| `<release>-controller` | `cert-manager-controller` | reconciles Certificate/Issuer/Order/Challenge, signs CSRs, runs the ingress-shim |
| `<release>-webhook` | `cert-manager-webhook` | validating + mutating admission webhook (Service `:443` -> container `10250`) |
| `<release>-cainjector` | `cert-manager-cainjector` | injects the webhook's CA into the webhook configurations |
| _(no deployment)_ | `cert-manager-acmesolver` | launched on demand by the controller for ACME http-01 challenges; its image is passed via `--acme-http01-solver-image` (digest) |

The **webhook self-bootstraps its serving CA** (the `dynamic` serving-cert source):
it generates a CA, stores it in the Secret `<release>-webhook-ca`, and serves TLS.
The **cainjector** copies that CA into the `caBundle` of the Validating and Mutating
webhook configurations (they carry the `cert-manager.io/inject-ca-from-secret`
annotation). So **no external cert-manager / no self-dependency** is required. The
v1.20 CRDs are conversion-webhook-free, so no CA injection on the CRDs is needed;
they install from the chart's `crds/` directory (Helm applies them before templates).

## Smoke test (SelfSigned)

```sh
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: selfsigned }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: example, namespace: cert-manager }
spec:
  secretName: example-tls
  issuerRef: { name: selfsigned, kind: ClusterIssuer }
  commonName: example.local
  dnsNames: [example.local]
EOF

kubectl wait --for=condition=Ready certificate/example -n cert-manager --timeout=120s
kubectl get secret example-tls -n cert-manager   # populated tls.crt / tls.key
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.<component>.repository` | `ghcr.io/quenchworks/images/cert-manager-<component>` | one block per controller/webhook/cainjector/acmesolver |
| `image.<component>.digest` | (CI-maintained) | signed multi-arch index |
| `clusterResourceNamespace` | `""` (release namespace) | where ClusterIssuer-owned Secrets live |
| `leaderElection.namespace` | `""` (release namespace) | self-contained; no kube-system write grant needed |
| `controller.replicaCount` | `1` | |
| `controller.enableCertificateOwnerRef` | `false` | GC the TLS Secret when its Certificate is deleted |
| `controller.dns01RecursiveNameservers` | `""` | DNS01 self-check resolvers |
| `webhook.securePort` | `10250` | HTTPS admission port (Service exposes `:443`) |
| `webhook.failurePolicy` | `Fail` | `Ignore` to fail-open |
| `cainjector.replicaCount` | `1` | |
| `rbac.create` | `true` | required: cluster-wide cert-management + webhook injection |
| `serviceAccount.create` | `true` | one SA per component |

## Verify the image

All four images are pinned by digest and cosign-signed (keyless). The same
identity applies to each component (`cert-manager-controller`,
`cert-manager-webhook`, `cert-manager-cainjector`, `cert-manager-acmesolver`);
swap the repository to verify the others:

```sh
cosign verify ghcr.io/quenchworks/images/cert-manager-controller \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/cert-manager-controller --owner quenchworks`.

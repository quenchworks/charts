# Quenchworks ingress-stack

Ingress with TLS out of the box, from QuenchWorks images (nonroot, 0 fixable
CVEs, pinned by digest, cosign-signed):

| Component | Chart | Role |
|---|---|---|
| ingress-nginx | `ingress-nginx` | the cluster's default IngressClass, `nginx` |
| cert-manager | `cert-manager` | issues and renews certificates |
| cluster CA | this stack | a self-signed root and the `ingress-ca` ClusterIssuer, cert-manager's default |

## Install

```bash
helm install edge oci://ghcr.io/quenchworks/charts/ingress-stack -n ingress --create-namespace
```

Then any Ingress with `kubernetes.io/tls-acme: "true"` and a `tls` section gets
a certificate signed by the stack's CA. Clients trust the root in Secret
`ingress-root-ca` (key `ca.crt`).

## Values

| Key | Default | Notes |
|---|---|---|
| `ingress-nginx.ingressClass.isDefaultClass` | `true` | Ingresses with no class use nginx |
| `ingress-nginx.controller.service.type` | `LoadBalancer` | `NodePort` or `ClusterIP` where no load balancer exists |
| `clusterIssuer.enabled` | `true` | the self-signed root and `ingress-ca` |
| `clusterIssuer.rootDuration` | `87600h` | the root CA's lifetime (10 years) |
| `cert-manager.controller.extraArgs` | default issuer `ingress-ca` | point the default at another issuer here |

## Notes

- `ingress-ca` is a private CA: browsers and outside clients do not trust it
  until you install the root. For public certificates, add an ACME
  ClusterIssuer and annotate Ingresses with `cert-manager.io/cluster-issuer`.
- The issuers are applied by a post-install Job once cert-manager's webhook
  answers, so `helm uninstall` leaves the `ingress-selfsigned` and `ingress-ca`
  ClusterIssuers and the root Certificate behind; delete them by hand.
- cert-manager's ClusterIssuer secrets live in the release namespace, so the
  root CA Secret is there too.

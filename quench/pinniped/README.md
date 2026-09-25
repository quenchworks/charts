# Pinniped Concierge

[Pinniped](https://pinniped.dev) gives a Kubernetes cluster federated login. The
Concierge trusts an identity provider (an OIDC issuer through a JWTAuthenticator, or a
TokenReview webhook through a WebhookAuthenticator) and exchanges a user's token for a
short-lived cluster credential. It needs no API server flags, so it works on managed
clusters too. This chart runs the Concierge on the QuenchWorks pinniped image, 0 fixable
CVEs, cosign-signed and pinned by digest; the same image carries the `pinniped` CLI.

## Install

```sh
helm install pinniped oci://ghcr.io/quenchworks/charts/pinniped -n pinniped-concierge --create-namespace
kubectl apply -f - <<'YAML'
apiVersion: authentication.concierge.pinniped.dev/v1alpha1
kind: JWTAuthenticator
metadata: { name: my-oidc }
spec:
  issuer: https://issuer.example.com
  audience: my-cluster-7c9e
YAML
pinniped get kubeconfig --concierge-authenticator-type jwt --concierge-authenticator-name my-oidc > user.yaml
```

Users run kubectl with `user.yaml`; the embedded `pinniped login` exec plugin gets them a
token from the issuer and a cluster credential from the Concierge. Grant them access with
ordinary RBAC on their username and groups.

## How it issues credentials

On clusters where it can see the controller manager (self-managed control planes), the
Concierge runs a kube cert agent pod next to it, reads the cluster signing key and issues
client certificates. Where it cannot (most managed clusters), `impersonationProxy.mode:
auto` starts an impersonation proxy behind a LoadBalancer Service instead, and kubeconfigs
point at the proxy.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `2` | Concierge replicas, spread across nodes |
| `impersonationProxy.mode` | `auto` | `auto`, `enabled` or `disabled` |
| `impersonationProxy.externalEndpoint` | `""` | address clients reach the proxy on |
| `impersonationProxy.service.type` | `LoadBalancer` | Service type for the proxy |
| `apiServingCertificate.*` | 30 days, renew at 25 | aggregated API serving cert lifetime |
| `logLevel` | `""` | `info`, `debug`, `trace` or `all` |

The CRDs (JWTAuthenticator, WebhookAuthenticator, CredentialIssuer) ship in `crds/`, so
Helm installs them once and does not upgrade or delete them. The API group suffix is
fixed at `pinniped.dev`. The Supervisor (a federation OIDC issuer across clusters) is not
part of this chart.

The release gate installs the chart on kind, requires both aggregated APIs Available and
the kube cert agent strategy Success, deploys local-user-authenticator from the same image
with one bcrypt user, wires a WebhookAuthenticator to it, and logs that user in with
`pinniped get kubeconfig --static-token` and `pinniped whoami`, which must report the
user and their group.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

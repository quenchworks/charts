# Quenchworks knative-operator

The [Knative Operator](https://github.com/knative/operator) 1.24.1 on the QuenchWorks image
(built from source, nonroot, CVE-gated at build, pinned by digest, cosign-signed). The operator
installs and upgrades Knative Serving and Knative Eventing from `KnativeServing` and
`KnativeEventing` resources.

The chart installs upstream's `operator.yaml` for the release: the two CRDs, the operator, its
webhook (the same image, `/webhook`), their RBAC and configuration. Kubernetes 1.35 or newer.

## Install

```bash
helm install knative-operator oci://ghcr.io/quenchworks/charts/knative-operator -n knative-operator --create-namespace
```

Then Knative Serving with the Kourier ingress:

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata: { name: knative-serving, namespace: knative-serving }
spec:
  ingress: { kourier: { enabled: true } }
  config: { network: { ingress-class: kourier.ingress.networking.knative.dev } }
```

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` | `ghcr.io/quenchworks/images/knative-operator` | one image for the operator and the webhook |
| `image.digest` | pinned | |

## Notes

- Only the operator is a QuenchWorks image. The Serving, Eventing and Kourier components it
  installs come from the release manifests carried in the image and use Knative's own images
  (`gcr.io/knative-releases`). Override them per component with `spec.registry` in the
  `KnativeServing` or `KnativeEventing` resource.
- One install per cluster: the cluster roles and bindings keep upstream's names.
- The webhook generates its own certificate (Secret `operator-webhook-certs`) and writes the CA
  into the CRD conversion webhook at startup.
- The CRDs are templates with `helm.sh/resource-policy: keep`: `helm upgrade` updates them, and
  `helm uninstall` leaves them, so the Knative installs they describe survive an uninstall.

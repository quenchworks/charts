# Quenchworks vertical-pod-autoscaler

Hardened [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
on one minimal, nonroot, 0-CVE image that carries all three components, built
from source and pinned by digest.

- **recommender** computes CPU and memory requests from observed usage (it needs
  metrics-server).
- **updater** evicts, or resizes in place, pods whose requests drift from the
  recommendation.
- **admission controller** writes the recommendation into new pods through a
  mutating webhook.

## Install

```sh
helm install vpa oci://ghcr.io/quenchworks/charts/vertical-pod-autoscaler -n vpa --create-namespace
```

The chart installs the `VerticalPodAutoscaler` and `VerticalPodAutoscalerCheckpoint`
CRDs from the 1.8.0 release. Then create a VPA:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app
spec:
  targetRef: { apiVersion: apps/v1, kind: Deployment, name: my-app }
  updatePolicy: { updateMode: "Off" }   # Off, Initial, Recreate, InPlaceOrRecreate
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/vertical-pod-autoscaler \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/vertical-pod-autoscaler --owner quenchworks`.

## Webhook certificate

The chart generates a CA and a serving certificate for the `<release>-webhook`
Service. At startup the admission controller registers its own
`vpa-webhook-config` MutatingWebhookConfiguration with that CA. The certificate
is regenerated on each upgrade and the controller restarts to pick it up.

## Configuration

Each of `recommender`, `updater` and `admissionController` takes `enabled`,
`resources` and `extraArgs` (passed to that component's command line, e.g.
`--memory-saver` for the recommender). Each runs one replica: upstream's leader
election is off by default.

RBAC is upstream's: the rules of every ClusterRole the 1.8.0 deploy manifests
bind to a component, merged into one ClusterRole per component.

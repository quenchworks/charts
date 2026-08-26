# Quenchworks KEDA

Hardened [KEDA](https://github.com/kedacore/keda) on a minimal, nonroot, 0-CVE
image, pinned by digest. KEDA scales any workload from zero to N off event
sources -- queues, streams, databases, Prometheus, cron and 60+ more -- by
driving a standard `HorizontalPodAutoscaler` from the `ScaledObject` /
`ScaledJob` CRDs.

## Install

```sh
helm install keda oci://ghcr.io/quenchworks/charts/keda -n keda --create-namespace
```

## Architecture

KEDA ships two binaries in **one** image. Each Deployment picks its binary with
an explicit `command` (the image has no shell, so binaries are exec'd directly):

| Deployment | Binary | Role |
|------------|--------|------|
| `<release>-operator` | `/usr/bin/keda` | reconciles ScaledObject/ScaledJob/TriggerAuthentication/CloudEventSource, creates and owns one HPA per ScaledObject, evaluates scalers, serves their values over mTLS gRPC (`:9666`) |
| `<release>-metrics-apiserver` | `/usr/bin/keda-adapter` | aggregated API server for `external.metrics.k8s.io` (Service `:443` -> container `6443`); answers the HPA controller by calling the operator's gRPC service |

Upstream also builds an admission-webhooks binary. The Quenchworks image does
**not** ship it, so this chart deploys no webhook and creates no
`ValidatingWebhookConfiguration`. ScaledObjects are validated by the operator at
reconcile time instead (an invalid one reports the failure in its status rather
than being rejected at admission).

The CRDs (`ScaledObject`, `ScaledJob`, `TriggerAuthentication`,
`ClusterTriggerAuthentication`, `CloudEventSource`, `ClusterCloudEventSource`)
install from the chart's `crds/` directory. They are ~740 KB of OpenAPI schema --
far too large to render as templates, which would push the release Secret past
Helm's 1 MiB limit. `crds/` content is applied by Helm before the templates and
is deliberately never touched again by upgrade or uninstall.

### Certificates

One keypair does three jobs: it secures the operator's gRPC metrics service, it
is the adapter's HTTPS serving certificate, and its CA is what the aggregation
layer pins in the APIService `caBundle`. **The chart issues it** -- a self-signed
CA plus one leaf covering every DNS form of both Services -- stores it in the
Secret `<release>-certs`, and reads that Secret back on upgrade so the material
never churns. No cert-manager dependency.

KEDA can generate the same material itself (`--enable-cert-rotation`), but its
rotator deliberately `exit(0)`s the first time it writes the Secret so the pod
restarts onto the new files, which costs a container restart on every fresh
install. This chart leaves it off. To rotate manually: delete the Secret, run
`helm upgrade`, restart both deployments.

Bringing your own certificates is supported via `certificates.existingSecret`
(must hold `ca.crt`/`tls.crt`/`tls.key` with SANs for both Services) plus
`apiService.caBundle`.

## Smoke test (cron trigger, no external system needed)

```sh
# 1. the adapter must actually be serving, or nothing ever scales
kubectl get apiservice v1beta1.external.metrics.k8s.io \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'   # True

# 2. a real CR round-trip
kubectl create deployment demo --image registry.k8s.io/pause:3.10 -n keda
kubectl apply -f - <<'EOF'
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata: { name: demo, namespace: keda }
spec:
  scaleTargetRef: { name: demo }
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
    - type: cron
      metadata: { timezone: UTC, start: "0 6 * * *", end: "0 20 * * *", desiredReplicas: "3" }
EOF

kubectl wait --for=condition=Ready scaledobject/demo -n keda --timeout=120s
kubectl get hpa -n keda    # keda-hpa-demo, created and owned by KEDA
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/keda` | one image, both binaries |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `clusterDomain` | `cluster.local` | used for the certificate SANs and the adapter's gRPC dial address |
| `operator.replicaCount` | `1` | |
| `operator.watchNamespace` | `""` (all namespaces) | set to restrict KEDA to one namespace |
| `operator.leaderElect` | `true` | Lease in the release namespace |
| `operator.grpcPort` | `9666` | mTLS metrics service the adapter dials |
| `operator.httpDefaultTimeout` | `""` | ms; scalers' HTTP timeout |
| `metricsApiserver.securePort` | `6443` | Service exposes `:443` |
| `certificates.validityDays` | `3650` | CA and leaf |
| `certificates.existingSecret` | `""` | bring your own; set `apiService.caBundle` too |
| `apiService.create` | `true` | `v1beta1.external.metrics.k8s.io` is a cluster singleton |
| `rbac.create` | `true` | required: cluster-wide read, `*/scale` write, HPA/Job lifecycle |
| `rbac.createHpaControllerBinding` | `true` | lets the kube-system HPA controller read external metrics |
| `serviceAccount.create` | `true` | one SA, shared by both deployments |

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/keda \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/keda --owner quenchworks`.

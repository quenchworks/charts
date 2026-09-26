# Dapr

[Dapr](https://dapr.io) gives applications building-block APIs (state, pub/sub,
bindings, service invocation, actors, workflows) through a sidecar. This chart installs
Dapr's control plane and configures its sidecar injector, all on the QuenchWorks dapr
image: daprd and the control-plane binaries built from source, nonroot, 0 fixable CVEs,
cosign-signed and pinned by digest.

It wraps **upstream's Dapr chart** (a dependency at the same version as the image)
instead of re-implementing it: the control plane's certificates (Sentry), the
injector's webhook and the scheduler's etcd cluster are upstream's own templates. This
chart only points every image, including the daprd sidecar the injector adds to your
pods, at the QuenchWorks image.

## Install

```sh
helm install dapr oci://ghcr.io/quenchworks/charts/dapr -n dapr-system --create-namespace
```

Then annotate a workload:

```yaml
metadata:
  annotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "orders"
    dapr.io/app-port: "8080"
```

## Values

Every upstream value is available under `dapr:` (see the
[Dapr Kubernetes docs](https://docs.dapr.io/operations/hosting/kubernetes/)); for
example `dapr.global.ha.enabled: true` for three replicas of each control-plane
service. `quenchworksImage` is the pinned image; the per-component `image.name` values
reference it.

The scheduler runs a 3-member etcd cluster with a 16Gi PVC each
(`dapr.dapr_scheduler.cluster.storageSize`).

The release gate installs the chart on kind, requires every control-plane pod Ready,
deploys an annotated pod, requires the injector to add the daprd sidecar from the
QuenchWorks image, and saves and reads back state through the sidecar with Dapr's
in-memory state store.

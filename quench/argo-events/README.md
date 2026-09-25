# Argo Events

[Argo Events](https://argoproj.github.io/events/) is event-driven automation for
Kubernetes. EventSources receive or poll events (webhooks, queues, schedules, cloud
events), Sensors wait on them and run triggers (Argo Workflows, any Kubernetes resource,
HTTP calls), and an EventBus carries events between them. This chart runs the controller
on the QuenchWorks argo-events image, which also carries the `argo` CLI for the
argoWorkflow trigger. The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by
digest.

## Install

```sh
helm install argo-events oci://ghcr.io/quenchworks/charts/argo-events -n argo-events --create-namespace
```

Then an EventBus in each namespace that runs EventSources and Sensors:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata: { name: default }
spec:
  jetstream:
    version: latest
    securityContext: { fsGroup: 1001 }   # the QuenchWorks nats image runs as uid 1001
```

## EventBus images

The controller builds JetStream EventBus pods from `eventBus.jetstream`: the QuenchWorks
nats image, plus upstream's `natsio/nats-server-config-reloader` and
`natsio/prometheus-nats-exporter` sidecars, pinned by digest. The two sidecars are not
QuenchWorks-hardened images yet. Point them at your own images if that matters for you.

The CRDs ship in `crds/`, which Helm applies on the first install only; apply them with
`kubectl apply --server-side -f crds/` before upgrading across app versions.

## Values

| Key | Default | Meaning |
|---|---|---|
| `namespaced` | `false` | watch only the release namespace (a Role instead of a ClusterRole) |
| `eventBus.jetstream.*` | see values | images and settings for JetStream EventBus pods |
| `rbac.aggregateToDefaultRoles` | `true` | let admin, edit and view manage the Argo Events kinds |
| `replicas` | `1` | leader election keeps one active |

Sensors that create Kubernetes resources run as `spec.template.serviceAccountName`, which
needs its own RBAC. Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind, creates a JetStream EventBus on the
QuenchWorks nats image, a webhook EventSource and a Sensor with a Kubernetes trigger, posts
to the webhook, and requires the trigger to create its ConfigMap.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

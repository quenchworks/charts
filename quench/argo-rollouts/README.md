# Argo Rollouts

[Argo Rollouts](https://argoproj.github.io/rollouts/) brings progressive delivery to
Kubernetes: the `Rollout` resource replaces a Deployment with canary and blue-green
strategies, gated by `AnalysisTemplate`s and run side by side with `Experiment`s, with
traffic shaped through ingresses and service meshes. This chart runs the controller on the
QuenchWorks argo-rollouts image. The image is nonroot, 0 fixable CVEs, cosign-signed and
pinned by digest.

## Install

```sh
helm install argo-rollouts oci://ghcr.io/quenchworks/charts/argo-rollouts -n argo-rollouts --create-namespace
kubectl get crd rollouts.argoproj.io
```

The CRDs ship in `crds/`, which Helm applies on the first install only. When the app
version moves, apply them before upgrading:

```sh
helm pull oci://ghcr.io/quenchworks/charts/argo-rollouts --untar
kubectl apply --server-side -f argo-rollouts/crds/
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `2` | leader election keeps one active |
| `namespaced` | `false` | watch only the release namespace (a Role instead of a ClusterRole) |
| `metrics.enabled` | `true` | Service for the metrics port (8090) |
| `extraArgs` | `[]` | more controller flags |
| `rbac.create` | `true` | the permissions upstream grants, traffic routers included |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind, applies a canary Rollout (a 50% step, then a
timed pause), changes its image, and requires the controller to step it through to a
healthy second revision.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

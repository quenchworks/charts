# kuberay

The KubeRay operator, which runs Ray on Kubernetes: `RayCluster` (a head and worker
groups), `RayJob` (a cluster that runs one job, then tears down) and `RayService`
(Ray Serve with zero-downtime upgrades), plus `RayCronJob`. On the QuenchWorks image:
hardened, nonroot, 0-CVE, pinned by digest and cosign-signed.

## Install

```sh
helm install kuberay oci://ghcr.io/quenchworks/charts/kuberay --namespace ray-system --create-namespace
```

Then create Ray resources in any namespace. The Ray pods run the Ray image you set in
each resource (`rayproject/ray` or your own build); this chart runs only the operator.

## CRDs

The four CRDs are in `crds/`, from KubeRay 1.7.1. Helm installs them on first install
and never upgrades or deletes them. When a new chart moves to a newer KubeRay, apply
its `crds/` with `kubectl apply --server-side -f`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `watchNamespaces` | `[]` | namespaces to watch; empty watches all |
| `featureGates` | `{}` | KubeRay feature gates, e.g. `{ RayJobDeletionPolicy: true }` |
| `extraArgs` | `[]` | extra flags, e.g. `--batch-scheduler=volcano` |
| `leaderElection.enabled` | `true` | required for more than one replica |
| `rbac.create` | `true` | the ClusterRole (upstream's rules) and the leader-election Role |

Metrics are served on the `<release>-kuberay` Service, port `metrics` (8080).

## Release gate

On kind, the gate installs the chart, checks the four CRDs, creates a `RayCluster`,
and requires the operator to reconcile it into a head Pod and a head Service.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

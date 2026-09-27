# Quenchworks gitops-stack

GitOps and delivery in one install, from QuenchWorks images (nonroot, 0 fixable
CVEs, pinned by digest, cosign-signed):

| Component | Chart | What it does |
|---|---|---|
| Argo CD | `argocd` | syncs the cluster to what Git says |
| Argo Rollouts | `argo-rollouts` | canary and blue-green releases |
| Argo Workflows | `argo-workflows` | container-native pipelines |
| Argo Events | `argo-events` | starts workflows from webhooks and other events |

The stack also creates a `gitops-sensor` ServiceAccount that may submit
Workflows, so an Argo Events Sensor can run a pipeline when a webhook fires.

## Install

```bash
helm install gitops oci://ghcr.io/quenchworks/charts/gitops-stack
```

Names are fixed (`gitops-argocd-server`, `gitops-workflows-server`, ...), so run
one stack per namespace. The controllers watch the whole cluster.

## A webhook that runs a pipeline

Create an EventBus named `default`, a webhook EventSource, and a Sensor with
`spec.template.serviceAccountName: gitops-sensor` whose trigger creates a
`Workflow`. The release gate in `.github/workflows/release-gitops-stack.yml`
does exactly this and waits for the workflow to succeed.

## Values

| Key | Default | Notes |
|---|---|---|
| `argocd.enabled` | `true` | any subchart value goes under `argocd.` |
| `argo-rollouts.enabled` | `true` | any subchart value goes under `argo-rollouts.` |
| `argo-workflows.enabled` | `true` | any subchart value goes under `argo-workflows.` |
| `argo-events.enabled` | `true` | any subchart value goes under `argo-events.` |
| `sensorServiceAccount.create` | `true` | the `gitops-sensor` ServiceAccount and its Role |

## Notes

- The Argo Workflows server is plain HTTP with server auth mode in the defaults
  of its chart; put it behind an authenticating proxy before exposing it.
- Argo CD's admin password is in the `argocd-initial-admin-secret` Secret.

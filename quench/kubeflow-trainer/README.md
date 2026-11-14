# Quenchworks kubeflow-trainer

[Kubeflow Trainer](https://github.com/kubeflow/trainer) 2.4.0 with
[JobSet](https://github.com/kubernetes-sigs/jobset) 0.13.0, both on QuenchWorks
images (built from source, nonroot, CVE-gated at build, pinned by digest,
cosign-signed). Kubeflow Trainer runs distributed training (PyTorch, JAX, MPI,
DeepSpeed) as `TrainJob` resources on `TrainingRuntime` and
`ClusterTrainingRuntime` templates; every TrainJob runs as a JobSet.

The chart installs both controllers, their 5 CRDs (`TrainJob`,
`TrainingRuntime`, `ClusterTrainingRuntime`, `OptimizationJob`, `JobSet`),
upstream's RBAC and configuration, and the webhooks of both.

## Install

```bash
helm install kubeflow-trainer oci://ghcr.io/quenchworks/charts/kubeflow-trainer -n kubeflow-system --create-namespace
```

Then a runtime and a job. Upstream ships ClusterTrainingRuntimes for PyTorch,
DeepSpeed, JAX, MLX and XGBoost in `manifests/base/runtimes` of the
kubeflow/trainer repository; they use upstream's framework images.

```yaml
apiVersion: trainer.kubeflow.org/v1alpha1
kind: TrainJob
metadata: { name: fine-tune }
spec:
  runtimeRef: { name: torch-distributed }
  trainer:
    numNodes: 2
    image: your/training-image
```

## Values

| Key | Default | Notes |
|---|---|---|
| `image.digest` | pinned | the trainer controller manager |
| `jobset.image.digest` | pinned | the JobSet controller |

## Notes

- Only the two controllers are QuenchWorks images. Training runtimes, the
  dataset and model initializers, and framework images are chosen per runtime.
- One install per cluster: resources keep upstream's names
  (`kubeflow-trainer-controller-manager`, `jobset-controller-manager`).
- Both controllers generate and rotate their own webhook certificates (into
  `kubeflow-trainer-webhook-cert` and `jobset-webhook-server-cert`); no
  cert-manager needed. Right after install the webhooks may refuse a few
  seconds of requests: retry the apply.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/` yourself before upgrading across releases.

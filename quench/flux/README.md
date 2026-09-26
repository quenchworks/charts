# Flux

[Flux](https://fluxcd.io) keeps a cluster in step with Git, OCI and Helm repositories.
This chart installs its four core controllers and their CRDs on QuenchWorks images,
each built from source: nonroot, read-only root filesystem, 0 fixable CVEs,
cosign-signed and pinned by digest.

| Controller | Version | Reconciles |
|---|---|---|
| source-controller | 1.9.5 | GitRepository, OCIRepository, HelmRepository, HelmChart, Bucket |
| kustomize-controller | 1.9.5 | Kustomization (with SOPS decryption) |
| helm-controller | 1.6.4 | HelmRelease |
| notification-controller | 1.9.4 | Provider, Alert, Receiver |

These are the versions Flux 2.9.5 ships. The image automation controllers and
source-watcher are not part of this chart.

## Install

```sh
helm install flux oci://ghcr.io/quenchworks/charts/flux -n flux-system --create-namespace
```

Then add a GitRepository and a Kustomization (NOTES.txt prints an example). The flux CLI
works against this install with `--namespace flux-system`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `controllers.<name>.enabled` | `true` | turn a controller off |
| `controllers.<name>.extraArgs` | `[]` | extra controller flags |
| `watchAllNamespaces` | `true` | reconcile Flux objects in every namespace |
| `clusterReconciler.enabled` | `true` | bind kustomize- and helm-controller to cluster-admin, as upstream does |
| `webhookReceiver.service.type` | `ClusterIP` | the Service for Receiver webhooks |
| `logLevel` | `info` | `debug`, `info` or `error` |

`clusterReconciler.enabled: true` gives the two appliers cluster-admin: they apply
whatever your repositories hold. To restrict them, set it to false and give each
Kustomization and HelmRelease a `serviceAccountName` with the roles it needs.

The CRDs ship in `crds/`, so Helm installs them once and does not upgrade or delete
them; apply a newer chart's `crds/` by hand when upgrading across Flux minors.

The release gate installs the chart on kind and runs three real reconciliations: a
GitRepository plus Kustomization that deploys podinfo, a HelmRelease that installs the
QuenchWorks opa chart from its OCI registry, and a notification Provider and Alert,
each of which must go Ready.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

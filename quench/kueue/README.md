# Quenchworks kueue

[Kueue](https://kueue.sigs.k8s.io) 0.20.6 on the QuenchWorks image (built from
source, nonroot, CVE-gated at build, pinned by digest, cosign-signed). It decides
when a batch workload may start and on which resource flavors: Jobs, JobSets,
RayJobs and Kubeflow jobs wait in a `LocalQueue` until their `ClusterQueue` has
quota, then Kueue unsuspends them.

The chart is upstream's release manifest (`manifests.yaml` of v0.20.6) with the
namespace and the image templated: the eleven CRDs, the controller, its webhooks
and certificate rotation, the visibility API server, and upstream's RBAC
including the aggregated `kueue-batch-admin`/`-user` roles.

## Install

```bash
helm install kueue oci://ghcr.io/quenchworks/charts/kueue -n kueue-system --create-namespace
```

NOTES shows a minimal `ResourceFlavor`, `ClusterQueue` and `LocalQueue`.

## Values

| Key | Default | Notes |
|---|---|---|
| `image.repository` / `.digest` | our image | pinned by digest |
| `replicaCount` | `1` | leader election is on; extra replicas are standbys |

The controller configuration is upstream's `kueue-manager-config` ConfigMap. To
enable integrations or change settings, edit `templates/kueue.yaml` in a fork or
patch the ConfigMap and restart `kueue-controller-manager`.

## Notes

- Object names are upstream's (`kueue-controller-manager`, `kueue-webhook-service`,
  the `kueue-*` ClusterRoles and webhook configurations), so install Kueue once per
  cluster.
- Kueue writes its own webhook certificate into Secret `kueue-webhook-server-cert`
  and the CA into both webhook configurations. Right after install the webhooks
  refuse calls for a few seconds until that certificate exists: retry a create
  that fails with a webhook error.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across Kueue releases.

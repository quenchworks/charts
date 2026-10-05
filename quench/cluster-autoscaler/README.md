# Quenchworks Cluster Autoscaler

Hardened [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler),
the SIG Autoscaling controller that adds nodes when pods cannot be scheduled and
removes nodes that stay underused. Every cloud provider is compiled into the image;
`cloudProvider` picks one. The chart runs one Deployment with leader election, keeps
the status ConfigMap and the lease in the release namespace, and grants the core,
provider-independent RBAC. The image is minimal, runs nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, ships 0-CVE, is
cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest,
never a tag. It keeps upstream's layout (binary at `/cluster-autoscaler`), so
upstream's chart can run it too.

## Install

`cloudProvider` is required. Provider settings go in `extraArgs`, credentials in
`extraEnvVars` or `extraEnvVarsSecret`. AWS with tag auto-discovery, for example:

```bash
helm install ca oci://ghcr.io/quenchworks/charts/cluster-autoscaler \
  --set cloudProvider=aws \
  --set 'extraArgs[0]=--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster' \
  --set 'extraArgs[1]=--balance-similar-node-groups'
```

A provider that keeps node groups in custom resources needs its RBAC added. Helm
replaces lists, so copy the default `rbac.clusterRules` from values.yaml and append,
for Cluster API:

```yaml
cloudProvider: clusterapi
rbac:
  clusterRules:
    # ...the defaults from values.yaml, then:
    - apiGroups: [cluster.x-k8s.io]
      resources: [machinedeployments, machinepools, machines, machinesets]
      verbs: [get, list, update, watch]
    - apiGroups: [cluster.x-k8s.io]
      resources: [machinedeployments/scale, machinepools/scale]
      verbs: [get, patch, update]
```

## Try it without a cloud: the kwok provider

The release gate runs the chart with `cloudProvider: kwok`, which creates simulated
nodes. Install the [kwok](https://kwok.sigs.k8s.io/) controller, then create two
ConfigMaps in the release namespace: `kwok-provider-config` (key `config`) and
`kwok-provider-templates` (key `templates`). The templates must be a `v1 List` of
Node objects; the provider rejects a single bare Node document. Each template's
`cluster-autoscaler.kwok.nodegroup/min-count` and `max-count` annotations size its
node group. `.github/workflows/release-cluster-autoscaler.yml` in the charts repo
has a working pair.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cluster-autoscaler \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/cluster-autoscaler --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `cloudProvider` | `""` | Required: aws, azure, gce, clusterapi, hetzner, kwok, ... |
| `extraArgs` | `[]` | Appended flags (`--nodes`, `--node-group-auto-discovery`, `--scale-down-*`, `--expander`). |
| `containerPort` | `8085` | `/metrics` and `/health-check` (`--address`). |
| `rbac.rules` | status ConfigMap + lease | Release-namespace Role. |
| `rbac.clusterRules` | core read set + node writes | See above for provider CRDs. |
| `replicaCount` | `1` | Extra replicas stand by through leader election. |
| `networkPolicy.allowExternal` | `false` | Only the release namespace reaches `/metrics`. |
| `podDisruptionBudget.enabled` | `false` | Turn on with two or more replicas. |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars`, `extraEnvVarsSecret`, `extraVolumes`, `sidecars`,
probe overrides, security contexts) work as in every Quenchworks chart.

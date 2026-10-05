# Quenchworks Polaris

Hardened [Fairwinds Polaris](https://github.com/FairwindsOps/polaris), the Kubernetes
configuration validator. The chart runs the Polaris dashboard as a Deployment on
port 8080. Each page load audits the cluster's workloads against Polaris's
best-practice checks (security contexts, probes, resource requests and limits,
image tags, RBAC) and `/results.json` serves the same audit as JSON. Polaris reads
the cluster through a read-only ClusterRole. The image is minimal, runs nonroot
(uid 1001) on a read-only root filesystem with all capabilities dropped, ships
0-CVE, is cosign-signed (keyless / Sigstore), and the chart pins it by the signed
digest, never a tag.

## Install

```bash
helm install polaris oci://ghcr.io/quenchworks/charts/polaris
kubectl port-forward svc/polaris 8080:8080
# http://127.0.0.1:8080/  and  http://127.0.0.1:8080/results.json
```

Use your own checks and exemptions (a full Polaris config file):

```bash
helm install polaris oci://ghcr.io/quenchworks/charts/polaris --set-file config.yaml=polaris.yaml
```

## Permissions

`rbac.clusterRules` grants get and list on every kind the built-in checks target
or read: pods, nodes, namespaces, configmaps, serviceaccounts, the workload
controllers, ingresses, network policies, PDBs, HPAs, and the four RBAC kinds.
Nothing can write. A kind Polaris cannot list fails the whole audit, so add a rule
when a custom resource owns pods in your cluster (for example Argo Rollouts):

```yaml
rbac:
  clusterRules:
    # keep the defaults from values.yaml, then add:
    - apiGroups: [argoproj.io]
      resources: [rollouts]
      verbs: [get, list]
```

The admission webhook mode is not part of this chart.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/polaris \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/polaris --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `config.yaml` | `""` | Full Polaris config, mounted at `/config/config.yaml`. Empty uses the built-in checks. |
| `config.existingConfigMap` | `""` | ConfigMap you manage, key `config.yaml`. |
| `extraArgs` | `[]` | Appended to `polaris dashboard` (for example `--display-name=prod`). |
| `rbac.clusterRules` | read-only set | See Permissions. |
| `service.type` / `.port` | `ClusterIP` / `8080` | |
| `networkPolicy.allowExternal` | `false` | The report names every workload's weaknesses; only the release namespace reaches it. |
| `ingress.enabled` | `false` | HTTP Ingress for the dashboard. |
| `replicaCount` | `1` | Stateless; more replicas add availability only. |
| `podDisruptionBudget.enabled` | `false` | Turn on with two or more replicas. |

The common pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`,
`tolerations`, `extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides,
security contexts) work as in every Quenchworks chart.

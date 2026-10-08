# Quenchworks Kubescape Operator

[Kubescape](https://kubescape.io) in-cluster: configuration (posture) scanning against the
NSA-CISA, MITRE and CIS frameworks, and vulnerability scanning of every image running in the
cluster. Every component is built from source by QuenchWorks on Wolfi, 0-CVE, cosign-signed and
pinned by digest.

```sh
helm install kubescape oci://ghcr.io/quenchworks/charts/kubescape-operator -n kubescape --create-namespace
```

| Component | Image | Role |
|---|---|---|
| operator | `kubescape-operator` 0.2.172 | Triggers scans at startup and when pods start new images |
| kubescape | `kubescape` 4.0.15 (`ksserver`) | Configuration scanning |
| kubevuln | `kubevuln` 0.3.501 | Builds SBOMs of running images and matches them to vulnerability data |
| storage | `kubescape-storage` 0.0.348 | Aggregated API server (`spdx.softwarecomposition.kubescape.io/v1beta1`) that keeps results as Kubernetes objects |

Results are ordinary API objects:

```sh
kubectl get workloadconfigurationscansummaries -A
kubectl get vulnerabilitymanifestsummaries -A
```

## Scope

This chart ships the scanning half of Kubescape. The node agent is opt-in
(`nodeAgent.enabled`): a privileged eBPF DaemonSet (root, host PID namespace, SYS_ADMIN and
friends, as upstream runs it) that learns what each container executes, opens and calls and
stores it as application profiles (`kubectl get applicationprofiles -A`). Runtime threat
detection, malware scanning, relevancy filtering, network policy generation and node scanning
stay off. The components talk
to each other by fixed Service names (`operator`, `kubescape`, `kubevuln`, `storage`), so install
one release per cluster. No data leaves the cluster: there is no backend account
(`keepLocal`). The storage API server's serving certificate comes from a CA the chart generates
on first install and keeps on upgrade.

## Values

| Key | Default | Notes |
|---|---|---|
| `clusterName` | `cluster` | Name shown on results |
| `excludeNamespaces` | `kube-system,kube-public,kube-node-lease` | Not scanned; the release namespace is always excluded |
| `continuousScanNamespaces` | `[]` | Re-scan Deployments here as soon as they change |
| `storage.persistence.enabled` | `true` | Keep results (SQLite under `/data`) on a PVC; off is an emptyDir |
| `scheduler.scanOnInstall` | `true` | A post-install Job triggers the first configuration and vulnerability scan |
| `scheduler.enabled` / `scheduler.schedule` | `true` / `17 3 * * *` | CronJob that repeats both scans through the operator API |
| `kubevuln.maxImageSize` | `5368709120` | Larger images are skipped (bytes) |
| `kubevuln.scanTimeout` | `5m` | Per-image scan timeout |
| `nodeAgent.enabled` | `false` | The eBPF node agent and its application profiles |
| `nodeAgent.learningPeriod` / `updatePeriod` / `maxLearningPeriod` | `2m` / `10m` / `24h` | Delay before recording a container, profile write interval, end of learning |

## Testing

The release workflow installs the chart in kind, waits for the storage APIService to become
available, starts a workload, and requires a configuration scan summary and a vulnerability
manifest to appear through the storage API. With the node agent on, it execs into the workload
while the agent learns and requires the workload's application profile to record that exec.

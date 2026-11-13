# Quenchworks victoriametrics-operator

The [VictoriaMetrics Operator](https://github.com/VictoriaMetrics/operator) 0.75.2
on QuenchWorks images (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). It runs VMSingle, VMCluster, VMAgent, VMAlert, VMAuth,
Alertmanager and VictoriaLogs from Kubernetes resources, and scrapes targets
described by VMServiceScrape, VMPodScrape or the Prometheus Operator's
ServiceMonitor and PodMonitor objects.

The chart installs the 26 `operator.victoriametrics.com` CRDs (upstream's
description-free bundle from the release tag, which keeps the Helm release under
its 1 MiB limit), the operator Deployment and upstream's RBAC.

## Install

```bash
helm install vm-operator oci://ghcr.io/quenchworks/charts/victoriametrics-operator -n monitoring --create-namespace
```

Then a VMSingle and an agent that writes every scrape into it:

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMSingle
metadata: { name: main }
spec: { retentionPeriod: "1" }
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAgent
metadata: { name: main }
spec:
  selectAllByDefault: true
  remoteWrite: [{ url: "http://vmsingle-main:8429/api/v1/write" }]
```

## Values

| Key | Default | Notes |
|---|---|---|
| `configReloader.repository` / `.digest` | our image | `VM_CONFIG_RELOADER_IMAGE`, the sidecar in every pod the operator runs |
| `vmsingleImage` | our `victoriametrics` 1.156.0 | `VM_VMSINGLEDEFAULT_IMAGE` / `_VERSION`; `null` keeps upstream's default |
| `watchNamespaces` | `[]` | `WATCH_NAMESPACE`; empty watches every namespace |
| `logLevel` | `info` | `--zap-log-level` |
| `extraArgs` | `[]` | more operator flags, e.g. `--client.qps=100` |
| `replicaCount` | `1` | above 1 turns on `--leader-elect` |
| `rbac.create` | `true` | upstream's ClusterRole plus a leader-election Role |

## Notes

- VMAgent, VMAlert, VMAuth, VMCluster and VictoriaLogs keep upstream's
  `victoriametrics/*` images unless you set `spec.image` on them; QuenchWorks
  publishes single-node `victoriametrics` and `victorialogs` today.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across operator
  releases.
- The validating webhook is off (upstream's default without cert wiring).

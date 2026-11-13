# Quenchworks grafana-operator

The [Grafana Operator](https://github.com/grafana/grafana-operator) 5.25.0 on the
QuenchWorks image (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). It runs Grafana instances and manages their dashboards,
datasources, folders, library panels, alert rule groups, contact points,
notification policies and service accounts from Kubernetes resources. It can
also manage a Grafana it does not run (`spec.external` on a Grafana resource).

The chart installs the 13 `grafana.integreatly.org` CRDs, the operator
Deployment and upstream's RBAC from the release tag.

## Install

```bash
helm install grafana-operator oci://ghcr.io/quenchworks/charts/grafana-operator -n grafana --create-namespace
```

Then a Grafana and a dashboard:

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata: { name: main, labels: { dashboards: main } }
spec: {}
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata: { name: hello }
spec:
  instanceSelector: { matchLabels: { dashboards: main } }
  json: '{"title": "Hello", "panels": []}'
```

The admin login is in Secret `main-admin-credentials`
(`GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`).

## Values

| Key | Default | Notes |
|---|---|---|
| `grafanaImage.repository` / `.digest` | our `grafana` image | `RELATED_IMAGE_GRAFANA`: every Grafana without `spec.version` runs it |
| `watchNamespaces` | `[]` | `WATCH_NAMESPACE`; empty watches every namespace |
| `logLevel` | `info` | `--zap-log-level` |
| `logFormat` | `console` | `--zap-encoder`, `json` for log pipelines |
| `extraArgs` | `[]` | more operator flags, e.g. `--max-concurrent-reconciles=4` |
| `replicaCount` | `1` | above 1 turns on `--leader-elect` |
| `rbac.create` | `true` | upstream's ClusterRole plus a leader-election Role |
| `networkPolicy.enabled` | `true` | allows metrics (8080) and probes (8081) |

## Notes

- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across operator
  releases.
- A Grafana resource that sets `spec.version` to a tag runs
  `docker.io/grafana/grafana:<tag>`, not our image. Set it to an image reference
  with a digest (`ghcr.io/quenchworks/images/grafana@sha256:...`) to stay on
  hardened images.
- The operator runs the Grafana pod as uid 10001 on a read-only root
  filesystem; our Grafana image works under that.

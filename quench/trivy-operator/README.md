# Trivy Operator

[Trivy Operator](https://aquasecurity.github.io/trivy-operator) scans a Kubernetes
cluster continuously with Trivy and stores the results as custom resources:
VulnerabilityReport, ConfigAuditReport, RbacAssessmentReport, ExposedSecretReport and
SbomReport. This chart runs it on the QuenchWorks trivy-operator image, and its scan
Jobs run the QuenchWorks trivy-scanner image (the trivy build plus a busybox shell, which
the scan Job command line needs). Both are nonroot, 0 fixable CVEs, cosign-signed.

## Install

```sh
helm install trivy-operator oci://ghcr.io/quenchworks/charts/trivy-operator \
  --namespace trivy-system --create-namespace
kubectl get vulnerabilityreports -A
```

The operator reads its settings from ConfigMaps and Secrets with fixed names in its own
namespace, so install one release per namespace. CRDs ship with the chart.

## What it scans

| Scanner | Default | Report |
|---|---|---|
| vulnerabilities | on | VulnerabilityReport (per container image) |
| config audit | on | ConfigAuditReport (workloads, Services, RBAC, NetworkPolicy, ...) |
| RBAC assessment | on | RbacAssessmentReport |
| exposed secrets | on | ExposedSecretReport |
| SBOM | on | SbomReport |
| infra assessment, compliance | off | need the node collector, a privileged hostPath pod on an image outside this catalog |

Scan Jobs download the vulnerability databases from `trivy.dbRepository` and
`trivy.javaDbRepository`; mirror them for air-gapped clusters.

## Values

| Key | Default | Meaning |
|---|---|---|
| `targetNamespaces` | `""` | namespaces to scan, comma-separated; empty is all |
| `excludeNamespaces` | `kube-system` | namespaces to skip |
| `scanners.*` | see table | which scanners run |
| `scanJob.concurrentLimit` | `3` | parallel scan Jobs |
| `trivy.repository`, `trivy.tag` | QuenchWorks trivy-scanner `0.75.0@sha256:...` | the scanner image; the operator composes `repository:tag`, so the tag carries the digest |
| `operatorConfig` | `{}` | extra `OPERATOR_*` settings |

The operator pod runs with a read-only root filesystem and all capabilities dropped;
scan Jobs get the same container security context.

The release gate installs the chart on kind, deploys a workload in a scanned namespace,
and requires a VulnerabilityReport and a ConfigAuditReport for it, produced by a scan Job
on the QuenchWorks trivy-scanner image.

## Upgrading to 0.0.6

0.0.6 moves the operator from 0.34.0 to 0.35.0 (upstream changed no CRDs, RBAC or
settings; it fixes ConfigMap content in config audits) and its scan Jobs from
trivy-scanner `0.74.0`, a tag no longer rebuilt or scanned, to `0.75.0` pinned by
digest, the trivy line 0.35.0 pairs with. A plain `helm upgrade` is enough. Because the
tag now carries the digest, reports show the scanner digest in
`report.scanner.version` instead of `0.75.0`. If you set `trivy.tag` yourself, use a
trivy-scanner version that is still published, ideally as `<version>@sha256:...`.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

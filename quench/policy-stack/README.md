# Quenchworks policy-stack

Kubernetes policy in one install:

- [Kyverno](https://kyverno.io) enforces or audits ClusterPolicies at admission and in
  background scans, and writes the results as PolicyReports.
- [Policy Reporter](https://kyverno.github.io/policy-reporter/) serves those results over a
  REST API and Prometheus metrics, and pushes new violations to Slack, Loki, Elasticsearch,
  webhooks and more.
- [Polaris](https://polaris.docs.fairwinds.com) audits every workload against configuration
  best practices (privileged containers, missing probes, `:latest` tags, ...) in a dashboard.

Every image is minimal, nonroot, 0-CVE, cosign-signed and pinned by digest.

## Install

One per cluster (Kyverno's webhooks and CRDs, and every component's ClusterRole, are
cluster-wide):

```bash
helm install policy oci://ghcr.io/quenchworks/charts/policy-stack -n policy --create-namespace
```

Then add policies, for example an audit-only rule:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: require-team-label}
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team-label
      match: {any: [{resources: {kinds: [Pod]}}]}
      validate:
        message: "every Pod must carry the label team"
        pattern: {metadata: {labels: {team: "?*"}}}
```

Results:

```bash
kubectl -n policy port-forward svc/policy-policy-reporter 8081:8080
curl 'http://127.0.0.1:8081/v1/namespaced-resources/results'
kubectl -n policy port-forward svc/policy-polaris 8080:8080   # Polaris dashboard
```

## Values

| Key | Default | Notes |
|---|---|---|
| `kyverno.*` | | Passed to the kyverno chart. |
| `policy-reporter.enabled` | `true` | Targets go under `policy-reporter.config`. |
| `polaris.enabled` | `true` | |
| `ingress.enabled` | `false` | Fronts the Polaris dashboard unless `ingress.serviceName` says otherwise. |

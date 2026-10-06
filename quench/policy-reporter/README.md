# Quenchworks Policy Reporter

Hardened [Policy Reporter](https://github.com/kyverno/policy-reporter), Kyverno's
PolicyReport aggregator. It watches the PolicyReport and ClusterPolicyReport results that
Kyverno (or another policy engine) writes, serves them over a REST API and as Prometheus
metrics (`policy_report_result`), and can push new violations to Slack, Loki,
Elasticsearch, webhooks and more. The image is minimal, runs nonroot (uid 1001) on a
read-only root filesystem with all capabilities dropped, ships 0-CVE, is cosign-signed
(keyless / Sigstore), and the chart pins it by the signed digest.

This chart ships the core only; the web UI is a separate upstream project.

## Install

```bash
helm install policy-reporter oci://ghcr.io/quenchworks/charts/policy-reporter \
  -n policy-reporter --create-namespace
kubectl -n policy-reporter port-forward svc/policy-reporter 8080:8080
curl 'http://127.0.0.1:8080/v1/namespaced-resources/results?namespaces=default'
curl http://127.0.0.1:8080/metrics | grep policy_report_result
```

Notification targets go under `config`, in Policy Reporter's own config format (it is
written to a Secret, since targets carry webhook URLs and credentials):

```yaml
config:
  target:
    slack:
      webhook: https://hooks.slack.com/services/...
      minimumSeverity: high
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/policy-reporter \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|---|---|---|
| `rest.enabled` | `true` | REST API under `/v1`. |
| `metrics.enabled` | `true` | `/metrics` with `policy_report_result`. |
| `config` | `{crd: {targetConfig: false}}` | The whole config file. |
| `replicaCount` | `1` | Each pod keeps its own result cache, rebuilt on start. |
| `extraArgs` | `[]` | Any other Policy Reporter flag. |

RBAC is read-only cluster-wide (reports, namespaces, and the owners it resolves for a
result), plus leases and Secrets in the release namespace.

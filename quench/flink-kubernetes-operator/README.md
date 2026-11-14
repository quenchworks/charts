# Quenchworks flink-kubernetes-operator

The [Apache Flink Kubernetes Operator](https://github.com/apache/flink-kubernetes-operator) 1.16.1
on the QuenchWorks image (built from the Apache source release, nonroot, CVE-gated at build,
pinned by digest, cosign-signed). The operator runs Flink applications and session clusters from
`FlinkDeployment` and `FlinkSessionJob` resources, with savepoint-based upgrades and the job
autoscaler.

This is upstream's own chart (Apache-2.0) with three QuenchWorks defaults: the image is ours and
pinned by digest, the pods run as uid 1001, and the admission webhook is off.

## Install

```bash
helm install flink-kubernetes-operator oci://ghcr.io/quenchworks/charts/flink-kubernetes-operator -n flink --create-namespace
```

Then a session cluster on the QuenchWorks Flink image:

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata: { name: session, namespace: flink }
spec:
  image: ghcr.io/quenchworks/images/flink:2.3.0
  flinkVersion: v2_3
  serviceAccount: flink
  flinkConfiguration:
    kubernetes.entry.path: /usr/bin/docker-entrypoint.sh
  jobManager: { resource: { memory: "1024m", cpu: 0.5 } }
  taskManager: { resource: { memory: "1024m", cpu: 0.5 } }
```

## Values

All of upstream's values work. The ones QuenchWorks changes:

| Key | Default | Notes |
|---|---|---|
| `image.repository` | `ghcr.io/quenchworks/images/flink-kubernetes-operator` | operator and webhook |
| `image.digest` | pinned | takes precedence over `image.tag` |
| `podSecurityContext.runAsUser` / `runAsGroup` | `1001` | upstream: 9999 |
| `webhook.create` | `false` | upstream: true; needs cert-manager |

## Notes

- Only the operator is a QuenchWorks image. The Flink clusters run the image named in each
  `FlinkDeployment`. The QuenchWorks Flink image keeps its entrypoint at
  `/usr/bin/docker-entrypoint.sh`, so set `kubernetes.entry.path` as above (Apache's images use
  `/docker-entrypoint.sh`, Flink's default).
- The webhook validates and defaults resources. Its certificate comes from cert-manager: install
  cert-manager, then set `webhook.create=true`.
- By default the operator watches every namespace and creates the `flink` service account for jobs
  in its own namespace. Set `watchNamespaces` to limit it; upstream's chart then creates the job
  role in each.
- Helm installs the CRDs on first install and never upgrades or deletes them. Apply the new
  `crds/` before upgrading across operator releases.

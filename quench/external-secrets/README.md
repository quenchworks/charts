# Quenchworks External Secrets Operator

Hardened [External Secrets Operator](https://github.com/external-secrets/external-secrets)
(ESO) on a minimal, nonroot, 0-CVE image, pinned by digest. ESO syncs secrets from
external APIs (HashiCorp Vault, AWS/GCP/Azure secret managers, and many more) into
native Kubernetes Secrets, driven by `ExternalSecret` / `SecretStore` CRDs.

## Install

```sh
helm install eso oci://ghcr.io/quenchworks/charts/external-secrets \
  -n external-secrets --create-namespace
```

## Architecture

ESO is a single binary. This chart runs it as three Deployments that share one
ServiceAccount and differ only by their subcommand:

| Deployment | Args | Role |
|------------|------|------|
| `<release>-controller` | `external-secrets` | reconciles ExternalSecret/SecretStore/PushSecret and writes target Secrets |
| `<release>-webhook` | `external-secrets webhook` | validating-admission webhook (Service `:443` -> container `10250`) |
| `<release>-cert-controller` | `external-secrets certcontroller` | generates the webhook's self-signed CA, stores it in a Secret, and injects the caBundle into the ValidatingWebhookConfigurations |

Because the cert-controller manages the webhook CA, **no cert-manager dependency
is required**. The CRDs are installed from the chart's `crds/` directory (Helm
applies them before the templates).

## Smoke test (fake provider)

```sh
kubectl apply -n external-secrets -f - <<'EOF'
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata: { name: fake }
spec: { provider: { fake: { data: [{ key: "/example", value: "hello" }] } } }
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: example }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: fake, kind: SecretStore }
  target: { name: example-secret }
  data: [{ secretKey: greeting, remoteRef: { key: "/example" } }]
EOF

kubectl get secret -n external-secrets example-secret \
  -o jsonpath='{.data.greeting}' | base64 -d   # -> hello
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/external-secrets` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `controller.replicaCount` | `1` | set >1 with `controller.leaderElect=true` |
| `controller.leaderElect` | `false` | single active leader across replicas |
| `controller.processClusterStore` | `true` | reconcile `ClusterSecretStore` (drops flag + RBAC if false) |
| `controller.processClusterExternalSecret` | `true` | reconcile `ClusterExternalSecret` |
| `controller.processPushSecret` | `true` | reconcile `PushSecret` |
| `controller.processClusterPushSecret` | `true` | reconcile `ClusterPushSecret` |
| `webhook.port` | `10250` | HTTPS admission port (Service exposes `:443`) |
| `webhook.failurePolicy` | `Fail` | `Ignore` to fail-open |
| `webhook.certDir` | `/tmp/certs` | mount point for the cert-controller-managed TLS |
| `certController.requeueInterval` | `5m` | CA/caBundle reconcile interval |
| `rbac.create` | `true` | required: cluster-wide CRD + Secret access |
| `serviceAccount.create` | `true` | shared by all three deployments |

The image is pinned by digest and cosign-signed; verify with the command in the
post-install notes.

# Quenchworks Sealed Secrets

Hardened [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), the
Kubernetes controller that decrypts one-way-encrypted `SealedSecret` resources
into regular `Secret`s, on a minimal, nonroot, 0-CVE image built from source,
cosign-signed and pinned by digest. Runs the controller as a single-replica
Deployment, installs the `SealedSecret` CRD, and ships clean-room RBAC.

Because a `SealedSecret` can only be decrypted by the private key held inside
your cluster, it is safe to commit to Git — that is the whole point of the tool.

## Install

```bash
helm install sealed-secrets oci://ghcr.io/quenchworks/charts/sealed-secrets
```

Then seal something with the `kubeseal` client (install it from the
[upstream release page](https://github.com/bitnami-labs/sealed-secrets/releases)):

```bash
kubectl create secret generic mysecret --dry-run=client \
  --from-literal=password=s3cr3t -o yaml \
| kubeseal --controller-name sealed-secrets-sealed-secrets --format yaml \
> mysealedsecret.yaml

kubectl apply -f mysealedsecret.yaml
kubectl get secret mysecret      # created by the controller
```

## Back up the sealing keys

The controller generates an RSA key pair and stores it as a `Secret` in the
release namespace. **Lose it and no existing `SealedSecret` can ever be decrypted
again.** Back it up out of band:

```bash
kubectl get secret -n <release-ns> \
  -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealing-keys.yaml
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/sealed-secrets \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/sealed-secrets --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/sealed-secrets` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Keep at 1 — see [Architecture](#architecture). |
| `controller.keyPrefix` | `sealed-secrets-key` | Name prefix of the Secrets holding the sealing key pairs. |
| `controller.keySize` | `4096` | RSA key size for newly generated sealing keys. |
| `controller.keyRenewPeriod` | `""` | New-key generation period (e.g. `720h`). `0` disables rotation; empty uses the controller default (30d). |
| `controller.allNamespaces` | `true` | Watch every namespace. `false` = only the release namespace. |
| `controller.additionalNamespaces` | `""` | Comma-separated extra namespaces to watch. |
| `controller.labelSelector` | `""` | Only reconcile SealedSecrets matching this selector. |
| `controller.updateStatus` | `true` | Write the outcome to the SealedSecret's `status`. |
| `controller.logLevel` | `INFO` | `INFO` or `ERROR`. |
| `controller.logFormat` | `text` | `text` or `json`. |
| `controller.httpPort` | `8080` | Serves `/healthz`, `/v1/cert.pem`, `/v1/verify`, `/v1/rotate`. |
| `controller.metricsPort` | `8081` | Prometheus `/metrics`. |
| `controller.extraArgs` | `[]` | Extra flags, appended last. |
| `resources.requests` | `cpu 50m / mem 64Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | Controller HTTP port (cert fetch, verify). |
| `service.metricsPort` | `8081` | Metrics port. |
| `service.annotations` | `{}` | |
| `serviceAccount.create` | `true` | Token IS automounted — the controller needs API access. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `true` | ClusterRole/Binding for unsealing + namespaced key-admin Role. |
| `rbac.serviceProxier` | `true` | Namespaced Role letting `system:authenticated` proxy to the Service so `kubeseal` can fetch the **public** cert without cluster-admin. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the controller's two ports. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to in-cluster pods. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

One Deployment runs `/usr/bin/controller` (upstream `cmd/controller`) on
container ports `8080` (HTTP) and `8081` (metrics); the single Service exposes
both. Liveness and readiness both `httpGet /healthz` on the HTTP port, which
comes up once the controller has loaded or generated its sealing key.

The controller is a **singleton**: it owns the sealing keys and has no leader
election, so several replicas would race to create keys. `replicaCount` stays at
1 and there is deliberately no HPA and no PodDisruptionBudget (a `minAvailable: 1`
PDB on a single-replica singleton blocks node drains).

The `SealedSecret` CRD (`sealedsecrets.bitnami.com`, `v1alpha1`) installs from
the chart's `crds/` directory. Helm never deletes CRDs on uninstall, which is the
behaviour you want here — removing it would orphan every `SealedSecret` in the
cluster.

RBAC is authored from the controller's documented API needs, not copied:

* a **ClusterRole** with read on `bitnami.com/sealedsecrets`, `update` on their
  `status` subresource, write on core `Secrets` (the decrypted output it owns and
  keeps in sync), `create`/`patch` on Events, and read on namespaces;
* a **namespaced Role** with `create`/`list` on Secrets, kept out of the
  ClusterRole so sealing-key creation is scoped to the release namespace;
* optionally (`rbac.serviceProxier`) a **namespaced Role** binding
  `system:authenticated` to `get` + `services/proxy` on this one Service, which is
  how `kubeseal` fetches the public sealing certificate. The proxied endpoint
  serves only the public key, so it exposes no secret material.

Cluster-scoped names include the release namespace, so two releases in different
namespaces never collide.

The container runs nonroot (uid 1001) on a read-only root filesystem with all
capabilities dropped; the only mount is an `emptyDir` at `/tmp`.

## Configuration examples

Namespace-scoped controller (watch only its own namespace plus one more):

```yaml
controller:
  allNamespaces: false
  additionalNamespaces: "team-a"
```

Rotate the sealing key every 30 days and log JSON:

```yaml
controller:
  keyRenewPeriod: "720h"
  logFormat: json
```

Lock down cert distribution — no service proxying, clients must use
`kubeseal --cert` with an out-of-band certificate:

```yaml
rbac:
  serviceProxier: false
networkPolicy:
  allowExternal: false
```

Fetch the public sealing certificate for offline sealing in CI:

```bash
kubectl port-forward svc/sealed-secrets-sealed-secrets 8080:8080
curl -fsS http://127.0.0.1:8080/v1/cert.pem > sealing-cert.pem
kubeseal --cert sealing-cert.pem < secret.yaml > sealedsecret.yaml
```

## Uninstall

```bash
helm uninstall sealed-secrets
```

The sealing-key Secrets and the CRD survive, so reinstalling into the same
namespace keeps decrypting your existing `SealedSecret`s. Delete the CRD only if
you mean to abandon every `SealedSecret` in the cluster.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Sealed Secrets encrypts *to*
the cluster, so the trust boundary is the sealing key: back it up, restrict who
can read Secrets in the release namespace, and remember that anyone who can
create a `SealedSecret` can create the resulting `Secret`.

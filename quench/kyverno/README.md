# Quenchworks Kyverno

Hardened [Kyverno](https://github.com/kyverno/kyverno) on a minimal, nonroot,
0-CVE image, pinned by digest. Kyverno is a Kubernetes-native policy engine:
policies are Kubernetes resources, so validating, mutating, generating and
cleaning up cluster resources needs no new language and no sidecar in the
workload.

## Install

```sh
helm install kyverno oci://ghcr.io/quenchworks/charts/kyverno \
  -n kyverno --create-namespace
```

## Architecture

Kyverno ships several binaries; the QuenchWorks image ships all of them on `PATH`
under `/usr/bin`, with the admission controller as the default entrypoint. So this
chart is **one image, four Deployments**, each overriding `command` to pick its
binary, each with its own ServiceAccount and its own minimal RBAC:

| Deployment | Binary | Role |
|------------|--------|------|
| `<release>-admission-controller` | `kyverno` (entrypoint) | webhook server + policy engine; registers Kyverno's webhook configurations (Service `:443` -> container `9443`) |
| `<release>-background-controller` | `background-controller` | applies `generate` and `mutate-existing` rules out of band, driven by UpdateRequests |
| `<release>-cleanup-controller` | `cleanup-controller` | CleanupPolicy / DeletingPolicy schedules and the `cleanup.kyverno.io/ttl` label; serves its own webhook on `:443` |
| `<release>-reports-controller` | `reports-controller` | aggregates admission results and background scans into PolicyReports |

The image also carries `kubectl-kyverno` (the CLI, for `kyverno apply` in CI) and
`readiness-checker`. Neither needs a Deployment, so the chart does not make one.

Set `backgroundController.enabled`, `cleanupController.enabled` or
`reportsController.enabled` to `false` to drop what you do not use. The admission
controller is not optional.

### TLS is self-managed — no cert-manager

The admission controller generates its own CA and serving keypair on first start,
persists them in two Secrets in the release namespace
(`<release>-svc.<ns>.svc.kyverno-tls-ca` and `…-tls-pair`), serves HTTPS, and
writes the CA bundle into the webhook configurations itself. The cleanup
controller does the same for its own webhook. Nothing is mounted, nothing is
pre-seeded, and there is no cert-manager dependency — the namespaced Role granting
Secret write is what makes it work.

### Uninstalling is not just `helm uninstall`

Kyverno registers its webhook configurations at runtime under names compiled into
the binary (`kyverno-resource-validating-webhook-cfg` and friends), so Helm never
owned them and cannot delete them. Left behind, they are `failurePolicy: Fail`
webhooks pointing at a Service that no longer exists — the API server then rejects
every matching request, and removing Kyverno takes the cluster with it.

This chart ships a **post-delete hook Job** (with hook-scoped ServiceAccount and
RBAC, weighted to run after them) that deletes everything labelled
`webhook.kyverno.io/managed-by=kyverno`. It runs *after* the Deployments are gone,
so the controllers cannot re-create what it removed, and it runs in the release
namespace, which Kyverno's own webhooks exclude — so it works even when you
uninstall with an Enforce policy still active and the webhook actively blocking.
Verified in kind: uninstalling with a live Enforce policy left zero webhook
configurations and Pod creation kept working. Disable with
`webhookCleanup.enabled=false` only if you clean them up another way.

The CRDs and your policies are deliberately left in place: Helm never deletes
anything under `crds/`.

### CRDs

The 22 CRDs install from `crds/`, before the templates. Two notes:

* Helm stores the whole chart in its release Secret, and a Secret is capped at
  1 MiB. Kyverno's verbatim CRDs are 5.6 MB and land at ~1.475 MiB in that Secret
  — the install fails outright. The CRDs here therefore have their schema
  `description` fields stripped, which drops them to 1.9 MB / ~0.2 MiB in the
  Secret. Only `kubectl explain` prose is lost; every structural and validation
  field is untouched, so what the API server accepts is identical to upstream.
  Measured on a real install: release Secret 334,632 B, **714 KB of headroom**.
* Helm never *upgrades* CRDs. Crossing a Kyverno minor means applying them
  yourself first:

  ```sh
  helm show crds oci://ghcr.io/quenchworks/charts/kyverno --version <v> \
    | kubectl apply --server-side -f -
  ```

## Smoke test (prove both directions)

Ready pods are not proof. This is:

```sh
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: require-team-label }
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-team-label
      match: { any: [ { resources: { kinds: [Pod] } } ] }
      validate:
        message: "every Pod must carry the label `team`"
        pattern: { metadata: { labels: { team: "?*" } } }
EOF

kubectl wait --for=condition=Ready clusterpolicy/require-team-label --timeout=120s

# (a) REJECTED -- fails with the message above
kubectl run bad-pod  --image=ghcr.io/quenchworks/images/kubectl -n default --command -- sleep 3600

# (b) ADMITTED
kubectl run good-pod --image=ghcr.io/quenchworks/images/kubectl -n default \
  --labels team=platform --command -- sleep 3600
```

Wait for `status.ready` before testing: Kyverno has to add the rule to its webhook
configuration before the API server starts calling it.

## Extending RBAC for generate / cleanup rules

A policy that generates NetworkPolicies needs the background controller to be able
to write NetworkPolicies, and the chart cannot know that at install time. Each
component's ClusterRole is **aggregated**, so grant it from outside without editing
the chart:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno-generate-networkpolicies
  labels:
    rbac.kyverno.io/aggregate-to-background-controller: "true"
rules:
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["create", "update", "patch", "delete"]
```

The same label pattern works for `-admission-controller`, `-cleanup-controller`
and `-reports-controller`.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/kyverno` | one image for all four controllers |
| `image.digest` | (CI-maintained) | signed multi-arch index; never a tag |
| `admissionController.replicaCount` | `1` | raise for HA; leader election is automatic |
| `admissionController.webhookServerPort` | `9443` | Service publishes it as `:443` |
| `admissionController.admissionReports` | `true` | per-request reports the reports controller aggregates |
| `admissionController.generateValidatingAdmissionPolicy` | `true` | compile eligible policies to native VAPs so the API server evaluates them |
| `admissionController.forceFailurePolicyIgnore` | `false` | escape hatch for a wedged webhook; silently disables enforcement |
| `backgroundController.enabled` | `true` | needed for `generate` / `mutate-existing` |
| `cleanupController.enabled` | `true` | needed for CleanupPolicy / DeletingPolicy / TTL |
| `reportsController.enabled` | `true` | needed for PolicyReports |
| `reportsController.backgroundScan` | `true` | periodically re-evaluate existing resources |
| `config.resourceFilters` | see `values.yaml` | the release namespace and Kyverno's own objects are prepended automatically |
| `config.webhooks` | excludes `kube-system` | the release namespace is appended automatically |
| `rbac.bindViewRole` | `true` | binds the built-in `view` role; needed for `context.apiCall` and background scans |
| `webhookCleanup.enabled` | `true` | the post-delete Job described above |
| `metrics.service.enabled` | `true` | per-component `:8000` Services for a ServiceMonitor |

Plus the shared QuenchWorks surface (`nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `podAnnotations`, `extraEnvVars`, `extraVolumes`,
`sidecars`, `podSecurityContext`, `containerSecurityContext`, …), which applies to
all four Deployments.

## Security

* Nonroot (uid/gid 1001), `readOnlyRootFilesystem`, all capabilities dropped,
  `seccompProfile: RuntimeDefault`, no privilege escalation.
* The only writable paths are two `emptyDir`s at `/.sigstore` (the admission and
  reports controllers need a writable `TUF_ROOT` for image-verification policies).
* Images are signed with cosign (keyless) and pinned by digest.

```sh
cosign verify ghcr.io/quenchworks/images/kyverno \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

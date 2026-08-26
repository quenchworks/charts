# Quenchworks Argo Workflows

Hardened [Argo Workflows](https://github.com/argoproj/argo-workflows), the CNCF
container-native workflow engine for Kubernetes, on a minimal, nonroot, 0-CVE
image built from source, cosign-signed and pinned by digest.

The chart runs two Deployments from one image:

| Component | Binary | What it does |
|-----------|--------|--------------|
| workflow-controller | `/usr/bin/workflow-controller` | Watches `Workflow` / `CronWorkflow` objects and turns each step into a pod. |
| argo-server | `/usr/bin/argo server` | REST/gRPC API and the embedded web UI on 2746. |

and pins a third binary from the same image into every workflow pod:

| Injected | Binary | What it does |
|----------|--------|--------------|
| `init` + `wait` containers, and the wrapper around each step's own command | `/usr/bin/argoexec` | Stages artifacts, supervises the step, and reports the result back as a `WorkflowTaskResult`. |

## The executor image is the thing to get right

For every workflow pod the controller injects an `init` container, a `wait`
container, and rewrites the step's command to run through
`/var/run/argo/argoexec`. All three come from one image, and if nobody tells the
controller which one, it falls back to `quay.io/argoproj/argoexec:<version>` —
an image QuenchWorks does not build, scan or sign, and that a private or
air-gapped cluster cannot pull.

So the chart always passes

```
--executor-image=ghcr.io/quenchworks/images/argo-workflows@sha256:...
```

to the controller, resolved from `image.repository` + `image.digest`. The CLI
flag deliberately outranks the controller ConfigMap, so an operator editing
`controller.config` cannot accidentally un-pin the executor. Override
`executor.image.repository` / `executor.image.digest` only if you genuinely ship
`argoexec` as a separate image.

## Install

```bash
helm install wf oci://ghcr.io/quenchworks/charts/argo-workflows
```

Submit a workflow:

```bash
cat <<'EOF' | kubectl create -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-
spec:
  entrypoint: main
  templates:
    - name: main
      container:
        image: ghcr.io/quenchworks/images/busybox@sha256:96bfb56285a65f978985de00bec071bb9e52d3c588cd26febed64ff36651c526
        command: ["/bin/echo"]
        args: ["hello from argo"]
EOF

kubectl get workflows -w
```

Reach the API and the UI:

```bash
kubectl port-forward svc/wf-argo-workflows-server 2746:2746
curl http://127.0.0.1:2746/api/v1/info
```

## Security: read this before exposing the server

`server.authModes` defaults to `["server"]`, the conventional chart default: the
API serves every request with the argo-server's **own** ServiceAccount. That
makes the bundled UI usable out of the box, and it means anyone who can reach
the Service can list, submit and delete workflows and read pod logs. It is fine
for a ClusterIP inside a trusted namespace. Before putting an Ingress or a
LoadBalancer in front of it, switch to:

* `server.authModes: ["client"]` — every caller presents their own Kubernetes
  bearer token and acts with their own identity, or
* `server.authModes: ["sso"]` — OIDC login, configured under `controller.config.sso`.

`server.secure` is `false` by default (plain HTTP on 2746) because TLS is
normally terminated at the ingress. Set it to `true` to have the server serve
HTTPS with a self-signed certificate; the probes follow automatically.

## Workflow pod RBAC

Argo's emissary executor reports each step's outcome by creating a
`WorkflowTaskResult` as the workflow pod's own ServiceAccount. Without that
permission the step runs, the container exits 0, and the workflow then fails
with `workflowtaskresults.argoproj.io is forbidden`.

The chart therefore creates a Role granting `create` + `patch` on
`workflowtaskresults` in the release namespace and binds it to the
ServiceAccounts named in `workflowRBAC.serviceAccountNames` (`default` out of the
box, since a Workflow that names no ServiceAccount runs as `default`).

To submit workflows into **another** namespace, replicate that Role and
RoleBinding there.

## CRDs

The eight `argoproj.io` CRDs (`Workflow`, `WorkflowTemplate`,
`ClusterWorkflowTemplate`, `CronWorkflow`, `WorkflowEventBinding`,
`WorkflowTaskSet`, `WorkflowTaskResult`, `WorkflowArtifactGCTask`) ship in
`crds/`, so Helm installs them once and never templates or deletes them.

These are the project's **minimal** CRDs, which is what upstream's own install
manifests use. The "full" variants carry the complete pod-spec schema inline and
are 7.4 MB, with `workflows.argoproj.io` alone at 3.2 MB — past etcd's per-object
limit, never mind Helm's 1 MiB release Secret. The minimal set is 110 KB total;
the packaged chart is 27 KB and its rendered manifest 15 KB, so the release
Secret has essentially the whole 1 MiB to spare. Validation of the omitted
fields is done by the controller and the server when a Workflow is submitted.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/argo-workflows \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/argo-workflows --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/argo-workflows` | One image for controller, server and executor. |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `executor.image.repository` | `""` | Empty → `image.repository`. |
| `executor.image.digest` | `""` | Empty → `image.digest`. |
| `executor.pullPolicy` | `IfNotPresent` | Pull policy for the injected workflow-pod containers. |
| `executor.resources` | `cpu 10m-500m / mem 32Mi-256Mi` | Resources for the injected `init` + `wait` containers. |
| `controller.replicaCount` | `1` | Extra replicas stand by via Lease-based leader election. |
| `controller.logLevel` | `info` | Also used for the injected executor containers and the server. |
| `controller.metricsPort` | `9090` | Prometheus metrics. |
| `controller.healthzPort` | `6060` | Built-in health server; the liveness probe targets it. |
| `controller.parallelism` | `0` | Max concurrently running workflows. `0` = unlimited. |
| `controller.config` | `{}` | Free-form workflow-controller configuration (`artifactRepository`, `workflowDefaults`, `persistence`, `sso`, …). Parsed strictly: an unknown key fails the controller loudly. |
| `controller.existingConfigMap` | `""` | Use your own ConfigMap instead of rendering one. |
| `controller.extraArgs` | `[]` | Extra controller flags. |
| `controller.resources` | `cpu 100m-1 / mem 128Mi-512Mi` | |
| `server.enabled` | `true` | Set `false` for a controller-only install. |
| `server.replicaCount` | `1` | |
| `server.authModes` | `["server"]` | `client`, `server`, `sso`. See the security note above. |
| `server.secure` | `false` | `true` → HTTPS with a self-signed certificate. |
| `server.baseHref` | `/` | For serving the UI under a sub-path behind a proxy. |
| `server.extraArgs` | `[]` | |
| `server.resources` | `cpu 50m-500m / mem 128Mi-512Mi` | |
| `server.service.type` | `ClusterIP` | |
| `server.service.port` | `2746` | API + UI. |
| `serviceAccount.create` | `true` | One ServiceAccount per component. |
| `serviceAccount.controllerName` / `.serverName` | `""` | Override the derived names. |
| `rbac.create` | `true` | Required: the controller manages pods cluster-wide. |
| `workflowRBAC.create` | `true` | Role letting workflow pods report their results. |
| `workflowRBAC.serviceAccountNames` | `["default"]` | ServiceAccounts in the release namespace to bind it to. |
| `ingress.enabled` | `false` | Fronts the argo-server Service. Read the security note first. |
| `ingress.className` / `.annotations` / `.hosts` / `.tls` | | Standard Ingress fields. |

Plus the usual quench-common pod-spec surface, applied to both Deployments:
`podLabels`, `podAnnotations`, `nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `priorityClassName`, `schedulerName`,
`terminationGracePeriodSeconds`, `updateStrategy`, `extraEnvVars`,
`extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`, `extraVolumeMounts`,
`initContainers`, `sidecars`, `lifecycleHooks`, `podSecurityContext`,
`containerSecurityContext`, `livenessProbe`, `readinessProbe`,
`customLivenessProbe`, `customReadinessProbe`, `customStartupProbe`.

## Notes

* Both components run nonroot (uid 1001) with a read-only root filesystem and
  all capabilities dropped. The server gets an `emptyDir` at `/tmp`, the only
  path it writes to.
* Both are pointed at the same ConfigMap with `--configmap`, so the server always
  reads the configuration the controller is running with.
* The chart is cluster-scoped: the controller watches and runs workflows in every
  namespace.

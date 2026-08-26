# tekton

Tekton Pipelines: Kubernetes-native CI/CD. Installs the `tekton.dev` CRDs, the
reconciler and the admission webhook, so a `TaskRun` becomes a plain Pod and a
`PipelineRun` becomes a graph of them. Hardened by QuenchWorks: built from source
on Wolfi, nonroot, read-only root filesystem, cosign-signed, pinned by digest.

```bash
helm install tekton oci://ghcr.io/quenchworks/charts/tekton
```

## One image, five container references

This is the part that makes or breaks a Tekton install. The controller does not
only run its own binary — it stamps helper images into every pod it creates:

| Injected as | Binary | Image |
| --- | --- | --- |
| `prepare` init container | `workingdirinit` | this chart's `image` |
| per-step wrapper | `entrypoint` | this chart's `image` |
| sidecar stopper | `nop` | this chart's `image` |
| results sidecar | `sidecarlogresults` | this chart's `image` |
| `place-scripts` init container (only for `script:` steps) | a POSIX shell | `shellImage` (our busybox) |

The QuenchWorks Tekton image carries all four helper binaries and symlinks them
at the `/ko-app/<helper>` paths Tekton hardcodes, so the chart points the
controller at **itself, by digest** through `-entrypoint-image`, `-nop-image`,
`-sidecarlogresults-image` and `-workingdirinit-image`. Left at their built-in
defaults those flags name upstream registry images we do not publish, and every
TaskRun would sit in `Init:ImagePullBackOff` while the controller and webhook
both reported Ready. A run is therefore pinned to exactly the digests this chart
was released with.

`-shell-image-win` is the one image we do not publish: it is only ever pulled for
a `script:` step scheduled onto a Windows node, and the controller refuses to
start with the flag unset, so it defaults to the Windows PowerShell image Tekton
itself pins. On a Linux-only cluster nothing pulls it.

## What gets installed

Two Deployments from the single image:

- `<release>-tekton-controller` — reconciles TaskRun/PipelineRun/CustomRun.
- `<release>-tekton-webhook` — defaulting + validating admission and CRD
  conversion.

The CRDs (`Task`, `TaskRun`, `Pipeline`, `PipelineRun`, `StepAction`,
`CustomRun`, `ResolutionRequest`, `VerificationPolicy`) ship in `crds/`, not as
templates: they total roughly 1.4 MB of OpenAPI schema, comfortably more than the
1 MiB a Helm release Secret can hold. Helm does not delete CRDs on uninstall, so
run history survives a reinstall.

### TLS: no cert-manager needed

The webhook issues its own CA and serving certificate on start, writes them to
`<release>-tekton-webhook-certs`, then patches that CA bundle **and** the
intercept rules into the three webhook configurations and into each CRD's
conversion stanza. The chart therefore ships those configurations with an empty
`caBundle` and no `rules` — a webhook entry with no rules intercepts nothing,
which is what keeps a fresh install from deadlocking on a webhook that has not
started yet. Confirm the injection actually happened, rather than assuming:

```bash
kubectl get validatingwebhookconfiguration validation.webhook.pipeline.tekton.dev \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | head -c 20
```

The webhook derives all three configuration names from
`webhook.admissionControllerName`, and they are cluster-scoped. **One Tekton
Pipelines install per cluster.**

## Configuration

Everything Tekton reads at runtime lives in ConfigMaps whose names it hardcodes,
so `.Values.config` is keyed by those literal names and each key becomes a
ConfigMap of that name in the release namespace:

```yaml
config:
  config-defaults:
    default-timeout-minutes: "30"
  feature-flags:
    enable-cel-in-whenexpression: "true"
```

ConfigMap data has to be strings, and the schema enforces it, so on the command
line use `--set-string config.feature-flags.enable-step-actions=true` rather than
`--set` (which would send a boolean and fail validation).

All of them are created even when empty — a missing one makes the component's
config watcher fail on start. Because the names are not release-prefixed, one
install per namespace. Set them through values rather than editing them in
place, or the next `helm upgrade` reverts your change.

| Key | Purpose |
| --- | --- |
| `image.repository` / `image.digest` | The Tekton image. Digest only, never a tag. |
| `shellImage.repository` / `.digest` | `place-scripts` shell image for `script:` steps. |
| `controller.replicaCount` | Reconciler replicas (leader-elected). |
| `controller.extraArgs` | Extra controller flags. |
| `controller.shellImageWin` | Windows `place-scripts` image; required by the controller. |
| `webhook.replicaCount` | Webhook replicas. |
| `webhook.failurePolicy` | `Fail` (default) or `Ignore`. |
| `webhook.admissionControllerName` | Base name of the three webhook configurations. |
| `config.*` | Tekton's config-* ConfigMaps, keyed by ConfigMap name. |
| `partOf` | `app.kubernetes.io/part-of`; the config webhook selects on it. |
| `rbac.create` | Required; the controller needs cluster-wide access to runs and pods. |
| `serviceAccount.*` | Per-component ServiceAccounts. |

Plus the usual quench-common surface: `podLabels`, `podAnnotations`,
`nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`,
`priorityClassName`, `resources`, `extraEnvVars`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`, `podSecurityContext`,
`containerSecurityContext`.

## Run something

```bash
kubectl apply -f - <<'EOF'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: hello
spec:
  steps:
    - name: say
      image: ghcr.io/quenchworks/images/busybox@sha256:e15887b82fd68a38d7570e8dd0687fc35e3e47507de89719210d8df394190e7f
      script: |
        echo "hello from tekton"
---
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: hello-run
spec:
  taskRef:
    name: hello
EOF

kubectl wait --for=condition=Succeeded --timeout=300s taskrun/hello-run
kubectl logs -l tekton.dev/taskRun=hello-run -c step-say
```

### Sidecars end the run pod in phase `Failed`

With the default `enable-kubernetes-sidecar: "false"`, Tekton stops a sidecar by
swapping its image to the `nop` image while leaving the sidecar's own `command`
(or generated script) in place. No distroless `nop` image — ours or upstream's —
can exec that command, so the sidecar container restarts once, exits non-zero and
the pod reports `Failed`. The **TaskRun still succeeds** and results still
propagate; only the pod object looks unhappy. Set

```yaml
config:
  feature-flags:
    enable-kubernetes-sidecar: "true"
```

to use native Kubernetes sidecar containers instead, which shut down cleanly.

## Not included

Remote resolvers (`tekton-pipelines-remote-resolvers`) and the CloudEvents
controller are separate Deployments in the upstream release and are not shipped
here. The binaries are in the image, so they can be added when there is a use for
them; a Task or Pipeline referenced with `resolver:` will not resolve until then.
Tekton's aggregated `tekton-aggregate-edit` / `tekton-aggregate-view`
ClusterRoles are likewise omitted — grant access to `tekton.dev` explicitly.

## Security

- Nonroot (uid/gid 1001), `readOnlyRootFilesystem`, all capabilities dropped,
  `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`.
- Every image referenced by the chart — including the ones injected into run
  pods — is pinned by digest.
- RBAC is authored per component: the webhook can only touch its own admission
  plumbing and certs Secret; the controller's grants stop at the run API surface
  and the pods/PVCs/StatefulSets a run needs.

```bash
cosign verify ghcr.io/quenchworks/images/tekton \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Links

- Chart source: https://github.com/quenchworks/charts
- Image source: https://github.com/quenchworks/images
- Upstream: https://github.com/tektoncd/pipeline

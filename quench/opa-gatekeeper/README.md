# OPA Gatekeeper

[OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) is the Kubernetes
admission controller for policies written in Rego. ConstraintTemplates define a policy
and the Constraint kind it creates; Constraints apply it to resources. Gatekeeper
enforces them in validating and mutating webhooks and audits what already exists. This
chart runs the webhook and audit Deployments on the QuenchWorks opa-gatekeeper image. The
image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

One Gatekeeper per cluster: the webhooks are cluster-wide.

```sh
helm install gatekeeper oci://ghcr.io/quenchworks/charts/opa-gatekeeper -n gatekeeper-system --create-namespace
kubectl get constrainttemplates
```

The webhook pods issue and rotate their own certificate (the Secret
`gatekeeper-webhook-server-cert`, a name Gatekeeper fixes) and write the CA into both
webhook configurations. The webhooks skip the release namespace, `exemptNamespaces`, and any
namespace labelled `admission.gatekeeper.sh/ignore`.

## Failure policy

`validatingWebhook.failurePolicy` is `Ignore` by default, as upstream ships it: if every
webhook pod is down, requests pass unchecked. Set `Fail` to enforce strictly, and keep
`replicas` at 2 or more with the PodDisruptionBudget.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `3` | webhook pods |
| `validatingWebhook.failurePolicy` | `Ignore` | `Ignore` or `Fail` |
| `mutatingWebhook.enabled` | `true` | Assign, AssignMetadata, ModifySet mutations |
| `audit.interval` | `60` | seconds between audits of existing resources |
| `exemptNamespaces` | `[]` | more namespaces the webhooks skip |
| `disabledBuiltins` | `["{http.send}"]` | OPA builtins turned off |
| `priorityClassName` | `system-cluster-critical` | with the ResourceQuota that allows it |

The CRDs ship in `crds/`, which Helm applies on the first install only; apply them with
`kubectl apply --server-side -f crds/` before upgrading across app versions. Pods run with
a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind, applies a required-labels ConstraintTemplate
and Constraint, and requires the webhook to deny an unlabelled pod, admit a labelled one,
and audit to report the violating pod created before the policy.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

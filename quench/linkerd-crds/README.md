# linkerd-crds

The linkerd-specific CustomResourceDefinitions from
[linkerd/linkerd2](https://github.com/linkerd/linkerd2), packaged on their own so
the control plane has the API surface it needs before it starts.

```sh
helm install linkerd-crds oci://ghcr.io/quenchworks/charts/linkerd-crds \
  -n linkerd --create-namespace
```

Install this **before** `quench/linkerd`.

## Why this chart exists

Linkerd's destination controller calls `k8s.InitializeAPI` with `ServiceProfile`,
`Server` and `ExternalWorkload` during startup
(`controller/cmd/destination/main.go`). When the apiserver does not know those
kinds it does not degrade, it exits:

```
level=fatal msg="Failed to initialize K8s API: the server could not find the requested resource"
```

The Deployment then never reaches Available and `helm install --wait` times out
reporting only `Available: 0/1`. These CRDs are a hard prerequisite.

## What is shipped, and what is not

Nine CRDs, all namespaced:

| Kind | Group |
|---|---|
| ServiceProfile | `linkerd.io` |
| Server, ServerAuthorization, AuthorizationPolicy | `policy.linkerd.io` |
| MeshTLSAuthentication, NetworkAuthentication | `policy.linkerd.io` |
| EgressNetwork, HTTPLocalRateLimitPolicy | `policy.linkerd.io` |
| ExternalWorkload | `workload.linkerd.io` |

**The Gateway API route CRDs are deliberately absent.** Upstream's own
`linkerd-crds` chart ships them, and they are 696KB of its 707KB. Three reasons
they are not here:

- `quench/gateway-api-crds` already owns those names. A cluster-scoped CRD with
  two owners belongs to whichever applied last, and `helm uninstall` of either
  owner can take the other's API surface with it.
- Helm stores the chart files and the rendered manifest in one release Secret,
  and Kubernetes caps a Secret at 1,048,576 bytes. The envoy-gateway chart
  walked into that ceiling once already.
- The routes are optional for linkerd; the nine CRDs here are not.

If your linkerd deployment routes with `HTTPRoute` or `GRPCRoute`, install
`quench/gateway-api-crds` alongside this chart.

## Provenance

`templates/crds.yaml` is generated, not hand-written:

```sh
uv run scripts/gen-linkerd-crds.py 26.8.4
```

Each CRD **spec** is upstream's byte for byte, because that is the API contract.
Only the metadata labels and annotations are this chart's, so no upstream library
chart is required; upstream's files call
`include "partials.annotations.created-by"`, which belongs to a library we do not
ship.

The release workflow runs the generator with `--check` and refuses to publish
when the shipped file and upstream disagree, so a hand-edit cannot ship. The
generator itself refuses to emit anything if the CRD set changes or if an
upstream library reference survives the rewrite.

## Values

| Key | Default | What it does |
|---|---|---|
| `crds.keep` | `true` | Stamps `helm.sh/resource-policy: keep` on every CRD. |

### The cost of `crds.keep: true`

Deleting a CRD cascade-deletes every object of that kind, so the default keeps
your `Server`, `ServerAuthorization` and `ServiceProfile` objects alive through a
`helm uninstall`. The price is that the CRDs survive still carrying the old
release's `meta.helm.sh/release-name` annotation, so reinstalling under a
**different** release name fails with `invalid ownership metadata`. Reinstall
with the same release name and namespace, or re-annotate:

```sh
kubectl annotate --overwrite crd servers.policy.linkerd.io \
  meta.helm.sh/release-name=<new-name> meta.helm.sh/release-namespace=<ns>
```

Set `crds.keep: false` only on throwaway clusters where losing the custom
resources is acceptable.

## Why `templates/`, not `crds/`

Helm never upgrades content in a `crds/` directory, which would make a
version-pinning chart a no-op on `helm upgrade`. Shipping them as ordinary
templates is what lets the bundle roll forward.

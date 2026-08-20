# Quenchworks gateway-api-crds

The [Gateway API](https://github.com/kubernetes-sigs/gateway-api) CustomResourceDefinitions,
packaged on their own so that every Gateway API implementation in the catalog binds to
**one pinned bundle** instead of each shipping its own copy.

**This chart has no image.** It installs nothing that runs: only CRDs and upstream's
`safe-upgrades` ValidatingAdmissionPolicy. There is no `image` block, no digest contract
with the image factory, and no `quench-common` dependency (that library chart exists to
assemble pod specs, and this chart renders none).

## Install

```sh
helm install gateway-api-crds oci://ghcr.io/quenchworks/charts/gateway-api-crds \
  -n gateway-system --create-namespace
```

CRDs are cluster-scoped, so the namespace only holds the Helm release secret. One release
per cluster.

## This chart owns the CRDs

Gateway API CRDs are **cluster-scoped singletons**. Two charts installing
`httproutes.gateway.networking.k8s.io` do not compose — whichever applies last wins, its
schema silently replaces the other's, and `helm uninstall` of either one can take the
whole API surface with it.

So: install this chart once per cluster, and **disable the bundled CRD installer in every
implementation chart** (Envoy Gateway, Contour, NGINX Gateway Fabric, kgateway, Istio).
The catalog's implementation charts do not install Gateway API CRDs; they document this
chart as a prerequisite. Do not make it a subchart dependency either — a subchart is
re-installed per implementation release, which is the same collision with extra steps.

### Which implementations this bundle actually serves

Read from each implementation's `go.mod` at the pinned tag, and checked against what a
v1.6.1 standard install really serves. **The v1.6.1 bundle serves only `v1` and `v1beta1`.**
The `v1alpha2` / `v1alpha3` entries are retained in the CRDs but marked
`served: false, deprecated: true`, so requests to those API versions 404 — verified on a
kind v1.36.1 cluster with `kubectl api-versions`.

| Implementation | built against | v1.6.1 standard? |
|---|---|---|
| `envoy-gateway` v1.9.0 | gateway-api v1.6.1 | yes — exact match |
| `kgateway` v2.4.2 | gateway-api v1.6.1 | yes — exact match |
| `nginx-gateway-fabric` v2.6.7 | gateway-api v1.5.1 | yes — the v1.5.1 standard kinds are a subset of v1.6.1's at the same `v1` versions |
| `istio` 1.30.3 | gateway-api v1.5.1 | yes — same |
| `contour` v1.33.6 | gateway-api v1.3.0 | **partially — see below** |

**Contour v1.33.6 is only partially compatible.** It pins gateway-api v1.3.0 and ships the
v1.3.0 **experimental** bundle in `examples/gateway/00-crds.yaml`. In v1.3.0, TCPRoute,
UDPRoute and TLSRoute were `v1alpha2` and BackendTLSPolicy was `v1alpha3` — none of which
v1.6.1 serves. So against this chart:

* Gateway, GatewayClass, HTTPRoute, GRPCRoute and ReferenceGrant work (all `v1`, plus
  `v1beta1` still served for the first three and ReferenceGrant);
* TCPRoute, UDPRoute, TLSRoute and BackendTLSPolicy do **not** — Contour asks for API
  versions this bundle no longer serves.

Do not assume tier 0.1 unblocks Contour outright. Either restrict Contour to HTTP/GRPC
routing on this bundle, or wait for a Contour release built against gateway-api v1.5+.
The other four are clean.

The forward direction is the general failure mode: a controller that needs a field only a
*newer* bundle defines, or an API version an older one still served. That is why the bundle
is pinned in one place — bump it here, once, and re-check this table against each
implementation's `go.mod`.

## Channels: what ships, and why standard only

Gateway API cuts two release channels. They are **alternatives, not layers**: both define
the same ten `gateway.networking.k8s.io` CRD names, and the experimental copies of those ten
carry extra fields on top of the standard schemas. There is no "install both".

Contents of v1.6.1, read from the release assets rather than the docs:

| CRD | standard | experimental | served versions (storage in bold) |
|---|---|---|---|
| `gatewayclasses` (GatewayClass, cluster-scoped) | yes | yes | **v1**, v1beta1 |
| `gateways` (Gateway) | yes | yes | **v1**, v1beta1 |
| `httproutes` (HTTPRoute) | yes | yes | **v1**, v1beta1 |
| `grpcroutes` (GRPCRoute) | yes | yes | **v1** |
| `tcproutes` (TCPRoute) | yes | yes | **v1** (v1alpha2 retained, not served) |
| `udproutes` (UDPRoute) | yes | yes | **v1** (v1alpha2 retained, not served) |
| `tlsroutes` (TLSRoute) | yes | yes | **v1** (v1alpha2, v1alpha3 retained, not served) |
| `backendtlspolicies` (BackendTLSPolicy) | yes | yes | **v1** (v1alpha3 retained, not served) |
| `listenersets` (ListenerSet) | yes | yes | **v1** |
| `referencegrants` (ReferenceGrant) | yes | yes | v1, **v1beta1** |
| `xbackends.gateway.networking.x-k8s.io` (XBackend) | — | yes | **v1alpha1** |
| `xbackendtrafficpolicies…` (XBackendTrafficPolicy) | — | yes | **v1alpha1** |
| `xmeshes…` (XMesh, cluster-scoped) | — | yes | **v1alpha1** |

**This chart ships the standard channel, and there is no `channel` toggle.** That is a
deliberate decision on three grounds, one of which is a hard limit rather than a preference.

**1. Standard is the right default.** As of v1.6 it is no longer just the four GA kinds:
TCPRoute, UDPRoute, TLSRoute, BackendTLSPolicy and ListenerSet all graduated into it at
`v1`. Every kind the catalog's implementations reconcile is in `standard`, so the
experimental channel would buy them nothing — and it would not rescue Contour either, whose
problem is an old *API version*, not a missing kind. Only `standard` carries upstream's API
stability guarantee — experimental fields and kinds can be removed in any minor release with
no deprecation window, which would make every Gateway API bump a potentially breaking one for
objects users already wrote. Upstream treats the crossover as dangerous enough to ship an
admission policy against it (below).

**2. A chart carrying both bundles cannot be installed at all.** Helm stores the chart files
*and* the rendered manifest in a single release Secret, and Kubernetes caps a Secret at
1 MiB (helm/helm#12277). Measured on v1.6.1, against a kind v1.36.1 cluster:

| chart contents | chart bytes | rendered manifest | release Secret | result |
|---|---|---|---|---|
| standard only | 1.20 MB | 1.17 MB | 842 KiB (80% of cap) | installs |
| both channels | 2.60 MB | 1.17 MB | ~1.48 MiB | `Secret "sh.helm.release.v1…" is invalid: data: Too long` |
| experimental only | 1.40 MB | 1.40 MB | ~1.0 MiB | at/over the cap |

So the experimental bundle is not shippable as a Helm *release* at any packaging, and adding
it would break `helm install` for everyone. Envoy Gateway's own `gateway-crds-helm` chart
hits the same wall and its README tells users to run `helm template … | kubectl apply` rather
than `helm install`. We would rather ship one channel that genuinely installs, upgrades and
passes an install gate.

**3. Rejected alternatives, and why.** Dropping the schema `description` fields shrinks the
standard bundle from 1.17 MB to 363 KB and would fit both channels comfortably — but
`GatewayClass.spec.description` and `XMesh.spec.description` are *real API fields*, so a
naive recursive strip deletes them from the schema, and the safe version needs a
schema-aware transform plus `kubectl explain` losing its prose for every Gateway API field.
Not worth it while one channel fits. Putting the CRDs in `crds/` would drop the manifest term
and land at ~41% of the cap, but `helm upgrade` never touches `crds/` content, which makes a
version-pinning chart a no-op on upgrade — see below.

### Known ceiling

842 KiB of 1 MiB is **80% of the cap, with roughly one Gateway API minor release of
headroom.** The standard bundle has grown 617 KB → 696 KB → 1024 KB → 1171 KB across v1.3,
v1.4.1, v1.5.1 and v1.6.1. When it stops fitting, the fix is the schema-aware
`description` strip described above (keeping the two real `description` *properties*), which
buys roughly a 3x reduction. The release workflow asserts the release-Secret size on every
run, so this surfaces as a clear CI failure at our end rather than an opaque
`data: Too long` at a user's `helm install`.

### If you need the experimental channel

Apply it directly, server-side, outside Helm — the same route upstream Envoy Gateway
documents. Delete the safe-upgrades policy first or the crossover is denied:

```sh
kubectl delete validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io
kubectl delete validatingadmissionpolicy safe-upgrades.gateway.networking.k8s.io
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/experimental-install.yaml
```

Do not do that on top of this chart's release: Helm would then own CRDs whose schemas no
longer match the manifest it recorded, and the next `helm upgrade` would revert them to
standard. Pick one owner. If experimental becomes a real catalog requirement, the answer is
a separate chart plus the description strip, not a toggle here.

### The safe-upgrades policy

`safeUpgradePolicy.enabled=true` (default) installs upstream's policy + binding. It is CEL
evaluated in the apiserver — no webhook, so no availability risk — and it denies, cluster
wide:

* any `gateway.networking.k8s.io` CRD write that moves from the standard channel to the
  experimental one, and
* any bundle older than v1.5. This copy's regex is stricter than its own message and rejects
  `v1.5.x` too (the experimental-channel copy gets this right) — an upstream quirk,
  irrelevant at v1.6.1, but it will bite a downgrade.

It gates **every** CRD create/update in the cluster whose `spec.group` is
`gateway.networking.k8s.io`, including writes from tools other than this chart. That is the
point, and it is why it is a values toggle rather than unconditional.

ValidatingAdmissionPolicy is GA in Kubernetes 1.30. Below that the template self-skips on
`.Capabilities.KubeVersion`, so leaving the toggle on is safe on older clusters.

## Helm's CRD handling: why these are templates, not `crds/`

Helm gives two places to put a CRD, and the difference decides whether this chart can do
its job at all.

| | `crds/` directory | regular `templates/` |
|---|---|---|
| `helm install` | applied first, by the client | applied in Helm's install order (CRDs early) |
| `helm upgrade` | **never touched** | applied, i.e. the bundle actually rolls forward |
| templating | none — static YAML only | full |
| `helm uninstall` | left in place | deleted, unless `helm.sh/resource-policy: keep` |
| counts toward the release Secret | chart files only | chart files **and** rendered manifest |

`crds/` is cheaper on size and it is what our `cert-manager` chart uses, but it is wrong
here: a chart whose entire purpose is *"pin and move the Gateway API version"* cannot use a
mechanism that makes `helm upgrade` a no-op. Users would bump the chart, see a new
`appVersion`, and still be running the old schemas — the exact CRD/controller skew this
chart exists to prevent. cert-manager gets away with it because its CRDs are incidental to a
chart that also ships three Deployments; here they are the entire product.

So the CRDs are regular templates, and the deletion risk that buys is handled directly:
every CRD is stamped `helm.sh/resource-policy: keep` (`crds.keep`, default `true`). Deleting
a CRD cascade-deletes every object of that kind, so without it a stray `helm uninstall`
would remove every Gateway, HTTPRoute and GRPCRoute in the cluster.

Two consequences worth knowing before you hit them:

* **`helm upgrade` does patch the CRDs.** `resource-policy: keep` only affects deletion.
  Expect schema changes to apply on upgrade — that is the feature.
* **Uninstall then reinstall needs the same release name.** The kept CRDs still carry the old
  release's `meta.helm.sh/release-name` / `-namespace` annotations, so reinstalling as a
  different release fails with `invalid ownership metadata`. Reuse the name and namespace, or
  re-annotate:
  ```sh
  for c in $(kubectl get crd -o name | grep gateway.networking); do
    kubectl annotate --overwrite "$c" \
      meta.helm.sh/release-name=gateway-api-crds \
      meta.helm.sh/release-namespace=gateway-system
  done
  ```

## Provenance

`templates/crds-standard.yaml` is the upstream release asset **byte for byte**. Document
order, comments and whitespace are untouched and nothing is re-serialised.

| File | Upstream URL | sha256 |
|---|---|---|
| `templates/crds-standard.yaml` | <https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml> | `24d931f22abd8e40c973264319ead7cfa09d0fb7716b7ab1ee2ff174cb063a73` |

For reference, the experimental asset this chart does **not** ship:
`experimental-install.yaml` sha256
`d7fa77650e4ef28fca0411536fcb5e237deb4d50301cfded3be49d9a1b7bbd02`.

Every inserted line is either at column 0 and starts with `{{- `, or is one of three lines
indented by four spaces, so the upstream bytes can be recovered mechanically. Auditing the
shipped template — this must print nothing and exit 0:

```sh
curl -fsSL -o up.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
sha256sum up.yaml                            # compare with the table above
sed -e '1,2d' \
    -e '/^{{- if /d' \
    -e '/^{{- end }}$/d' \
    -e '/^    {{- if \.Values\.crds\.keep }}$/,+2d' \
    templates/crds-standard.yaml | cmp - up.yaml
```

The release workflow runs exactly that on every push, plus a check that the checksum above
matches the asset it just fetched, and refuses to publish on a mismatch. A hand-edit of the
vendored blob, or an upstream re-cut tag, cannot ship silently.

The inserted lines, and nothing else:

1. a two-line `{{- /* GENERATED */}}` header;
2. `{{- if .Values.crds.keep }}` / `helm.sh/resource-policy: keep` / `{{- end }}` at indent
   4, inserted directly after each CRD's metadata `annotations:` key;
3. `{{- if and .Values.safeUpgradePolicy.enabled (semverCompare ">=1.30.0-0" ...) }}` around
   the ValidatingAdmissionPolicy and its Binding — placed outside their `---` separators so
   that disabling the policy leaves no empty document behind.

Bumping the Gateway API version means: fetch the asset, re-apply those three edits in place,
record the new checksum here and in `artifacthub.io/changes`, bump `appVersion`, re-check the
implementations' `go.mod` table above, and watch the workflow's release-Secret size check.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `crds.keep` | `true` | stamp `helm.sh/resource-policy: keep`; `false` lets `helm uninstall` cascade-delete every Gateway API object in the cluster |
| `safeUpgradePolicy.enabled` | `true` | upstream's `safe-upgrades` ValidatingAdmissionPolicy; self-skips below Kubernetes 1.30 |

`kubeVersion` is `>=1.29.0-0`: the v1.6.1 CRDs use CEL `x-kubernetes-validations` rules
throughout.

## Smoke test

```sh
kubectl get crd -o json | jq -r '
  .items[] | select(.spec.group | test("gateway.networking"))
  | "\(.metadata.name)\t\(.metadata.annotations["gateway.networking.k8s.io/channel"])\t\(.metadata.annotations["gateway.networking.k8s.io/bundle-version"])"'

# The schemas and their CEL rules must accept a real object.
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: smoke }
spec: { controllerName: example.com/not-a-real-controller }
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: smoke, namespace: default }
spec:
  gatewayClassName: smoke
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes: { namespaces: { from: Same } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: smoke, namespace: default }
spec:
  parentRefs: [{ name: smoke }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /smoke } }]
      backendRefs: [{ name: smoke-svc, port: 80 }]
EOF
```

Nothing reconciles them (no controller claims `example.com/not-a-real-controller`), which is
exactly what a CRD-only chart should be tested for.

## Verify the chart

```sh
cosign verify ghcr.io/quenchworks/charts/gateway-api-crds \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Gateway API is Apache-2.0; the upstream licence header is preserved at the top of the
template.

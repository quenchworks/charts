# Quenchworks istiod

The [Istio](https://istio.io) control plane -- `pilot-discovery`: the xDS
discovery server, the mesh certificate authority and namespace configuration --
on a minimal, nonroot, 0-CVE QuenchWorks image built from source, cosign-signed
and pinned by digest.

## Install

```sh
helm install istiod oci://ghcr.io/quenchworks/charts/istiod
```

The chart boots with zero configuration: the pod authenticates to the Kubernetes
API with its own ServiceAccount and becomes ready once the discovery server is
up (`:8080/ready`).

## Verify

```sh
kubectl port-forward svc/istiod 15014:15014
curl http://127.0.0.1:15014/version   # the stamped image version
curl http://127.0.0.1:15014/metrics   # pilot_* and istiod_* metrics
```

## What this chart deliberately does NOT ship

**No Istio CRDs.** VirtualService, DestinationRule, Gateway and friends are a
large bundle, and Helm stores the whole rendered release in one Secret capped at
1 MiB. Install the CRD bundle once per cluster from upstream's `istioctl`/base
manifest instead.

**No data plane.** Istio's sidecar/gateway image (`proxyv2`) is built from
Istio's own Bazel/clang Envoy fork and is not buildable outside their toolchain;
it is not in the QuenchWorks catalog yet. This chart is the control plane:
pair it with upstream proxy images if you must run a mesh today, or wait for the
QuenchWorks data plane. Shipping a control plane without saying so plainly would
be worse than not shipping it.

**No sidecar-injection webhook.** With no data-plane image to inject, the
webhook would exist only to fail. It lands with the data plane.

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` / `image.digest` | pinned | Image, always pinned by digest. |
| `replicaCount` | `1` | Stateless; scale out freely. |
| `command` / `args` | discovery on `:8080`/`:15014` | Override to pass pilot flags (e.g. `--trust-domain`, `--profiles`). |
| `service.xdsPort` / `xdsSecurePort` | `15010` / `15012` | xDS plaintext / TLS listeners (binary defaults). |
| `service.httpPort` / `monitoringPort` | `8080` / `15014` | Debug+ready / Prometheus metrics. |
| `rbac.create` | `true` | ClusterRole for the mesh read set + events. |
| `networkPolicy.*` | enabled, in-cluster only | `allowExternal: true` opens xDS ingress cluster-wide. |

Standard quench-common knobs (`nodeSelector`, `affinity`, `tolerations`,
`extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides, security contexts)
are supported as in every Quenchworks chart.

## Security

Runs as uid 1001, read-only root filesystem, all capabilities dropped. The
ClusterRole is read-only over the mesh resources plus `events` create/patch --
the least pilot-discovery needs to discover and report.

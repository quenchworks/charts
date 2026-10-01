# Quenchworks vcluster

Hardened [vCluster](https://github.com/loft-sh/vcluster) on a minimal, nonroot,
0-CVE image. The syncer is built from source, and so is the control plane it
runs: kube-apiserver and kube-controller-manager 1.36.4 from the Kubernetes tag,
with kine on SQLite as the store.

A virtual cluster has its own API server inside one namespace of the host. Pods
created in it are synced to that namespace and run on the host's nodes.

## Install

```sh
kubectl create namespace team-a
helm install team-a oci://ghcr.io/quenchworks/charts/vcluster -n team-a
```

Connect with the kubeconfig the syncer writes into the `vc-<release>` Secret:

```sh
kubectl -n team-a get secret vc-team-a -o jsonpath='{.data.config}' | base64 -d > vc.kubeconfig
kubectl -n team-a port-forward svc/team-a 8443:443 &
sed -i 's|server: .*|server: https://127.0.0.1:8443|' vc.kubeconfig
kubectl --kubeconfig vc.kubeconfig get ns
```

For access without a port-forward, set `service.type: LoadBalancer` (or NodePort)
and `vcluster.exportKubeConfig.server` to that address.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/vcluster \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/vcluster --owner quenchworks`.

## Configuration

`vcluster:` is the vCluster configuration (vcluster.yaml), rendered as it is
into the `vc-config-<release>` Secret. The syncer parses it strictly and applies
no defaults of its own, so the chart ships upstream's complete 0.37.2 default
config: change keys there, and do not add keys the 0.37 schema lacks (an unknown
key stops the syncer). One default differs from upstream: `telemetry.enabled` is
`false`.

Chart-side settings:

| Key | Default | Meaning |
|---|---|---|
| `persistence.size` | `5Gi` | Volume for the virtual cluster's state under `/data`. |
| `persistence.storageClass` | `""` | Storage class; empty uses the cluster default. |
| `resources` | 200m / 512Mi request, 2Gi limit | The syncer pod, which also runs the control plane. |
| `service.type` | `ClusterIP` | The `<release>` Service on 443. |

Keys under `vcluster.controlPlane.statefulSet` that select images, probes or
resources are read by upstream's chart only and have no effect here.

## Differences from upstream's chart

- The pod runs as uid 1001, not root.
- `/binaries` is baked into the image, so there is no initContainer copying
  Kubernetes binaries in.
- Kubernetes 1.36 only, the line this image carries.

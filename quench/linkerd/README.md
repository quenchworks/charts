# Quenchworks linkerd

[Linkerd](https://linkerd.io)'s control plane on minimal, nonroot, 0-CVE
QuenchWorks images built from source, cosign-signed and pinned by digest.
Tracks the EDGE release lines: upstream has not cut a stable release since
stable-2.14.10 (Feb 2024) and now gates stable builds commercially, so "last
three lines" here means the last three edge year.month lines.

## Install

```sh
helm install linkerd oci://ghcr.io/quenchworks/charts/linkerd
```

The default install boots the **destination** controller alone -- it needs no
certificate material and becomes ready on its own.

## Components

| Component | Default | Needs |
| --- | --- | --- |
| destination | on | nothing -- endpoints + service profiles over gRPC |
| identity | off | trust domain, trust anchors PEM, issuer Secret |
| policy-controller | off | serving-cert Secret; policy CRDs to be useful |
| heartbeat | off | a Prometheus URL |

### Enabling identity

Identity is the mesh certificate authority. One binary quirk made this
explicit rather than default-on: upstream's identity controller **exits 0 --
as a healthy-looking pod -- when its scheme or trust domain is unset**. The
chart refuses to render it half-configured:

```sh
openssl ecparam -name prime256v1 -genkey -noout -out key.pem
openssl req -new -x509 -key key.pem -out crt.pem -days 3650 -nodes \
  -subj "/CN=identity.linkerd.cluster.local"
kubectl create secret generic linkerd-identity-issuer \
  --from-file=crt.pem=crt.pem --from-file=key.pem=key.pem

helm upgrade linkerd oci://ghcr.io/quenchworks/charts/linkerd \
  --set identity.enabled=true \
  --set identity.trustDomain=identity.linkerd.cluster.local \
  --set-file identity.trustAnchorsPEM=crt.pem \
  --set identity.existingSecret=linkerd-identity-issuer
```

The trust anchors are rendered by the chart into a ConfigMap (key
`ca-bundle.crt`); the Secret keys are `crt.pem` and `key.pem` -- both verified
against upstream source at edge-26.8.4.

### Enabling policy-controller

The Rust policy server needs a serving certificate and only becomes useful
once the policy CRDs (`Server`, `ServerAuthorization`) exist -- they land with
the data-plane chart.

```sh
openssl req -new -x509 -nodes -days 3650 \
  -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout tls.key -out tls.crt -subj "/CN=linkerd-policy" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign,digitalSignature"
kubectl create secret generic linkerd-policy-tls \
  --from-file=tls.crt=tls.crt --from-file=tls.key=tls.key
```

## What this chart deliberately does NOT ship

**No data plane, yet.** proxy-injector, sp-validator and the linkerd-proxy
sidecar land in a follow-up chart, along with the policy CRDs. Nothing in this
chart injects or runs a proxy. The three QuenchWorks images (control plane,
policy controller, proxy) already exist; the chart wiring them as a mesh is
the part still being proven.

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `controllerImage.repository` / `digest` | pinned | Control-plane image (destination/identity/heartbeat share it). |
| `policyController.image.*` | pinned | Rust policy controller image. |
| `clusterDomain` | `cluster.local` | |
| `controllerLogLevel` | `info` | |
| `service.destinationPort` / `destinationAdminPort` | `8086` / `9996` | destination gRPC / admin+metrics. |
| `service.identityPort` / `identityAdminPort` | `8080` / `9990` | identity gRPC / admin. |
| `service.policyPort` / `policyAdminPort` | `8090` / `9990` | policy gRPC / admin. |
| `identity.*` | off | See above; all three inputs are required when on. |
| `policyController.*` | off | `existingSecret` (keys `tls.crt`/`tls.key`), `clusterNetworks`. |
| `heartbeat.*` | off | `prometheusUrl` required when on. |
| `rbac.create` | `true` | Read-only mesh watch set; identity's Secret read stays namespace-scoped. |
| `networkPolicy.*` | enabled, in-cluster only | |

Standard quench-common knobs (`nodeSelector`, `affinity`, `tolerations`,
`extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides, security contexts)
are supported as in every Quenchworks chart.

## Security

All components run as uid 1001, read-only root filesystems, all capabilities
dropped. The ClusterRole is read-only over the mesh watch set; the only secret
read is identity's, scoped to the release namespace. Identity and
policy-controller are off by default so a bare install grants nothing it does
not use.

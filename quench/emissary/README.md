# Quenchworks Emissary-ingress

Hardened [Emissary-ingress](https://github.com/emissary-ingress/emissary), the CNCF
Kubernetes API gateway built on Envoy. Listener, Host and Mapping resources configure
routing, TLS, authentication and rate limiting. The chart installs the
getambassador.io CRDs (v3alpha1, upstream's 4.x default) and the gateway Deployment
behind a LoadBalancer Service. The image carries Envoy 1.37 from Wolfi, Emissary's
Python control plane and Go entrypoint built from source. It runs nonroot (uid 8888)
on a read-only root filesystem with all capabilities dropped, ships 0-CVE, is
cosign-signed (keyless / Sigstore), and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install emissary oci://ghcr.io/quenchworks/charts/emissary \
  --namespace emissary --create-namespace
```

Nothing listens until you create a Listener. Plain HTTP routing to a Service:

```yaml
apiVersion: getambassador.io/v3alpha1
kind: Listener
metadata: {name: http, namespace: emissary}
spec: {port: 8080, protocol: HTTP, securityModel: XFP, hostBinding: {namespace: {from: ALL}}}
---
apiVersion: getambassador.io/v3alpha1
kind: Host
metadata: {name: any, namespace: emissary}
spec: {hostname: "*", requestPolicy: {insecure: {action: Route}}}
---
apiVersion: getambassador.io/v3alpha1
kind: Mapping
metadata: {name: my-app, namespace: default}
spec: {hostname: "*", prefix: /my-app/, service: my-app.default:80}
```

Without a Host, Emissary synthesizes one that redirects HTTP to HTTPS. Use port 8443
with `protocol: HTTPS` and a Host with a `tlsSecret` for TLS.

The CRDs carry `helm.sh/resource-policy: keep`: uninstalling the chart leaves them and
every Mapping and Host in place. Only one release per cluster can own them; set
`crds.enabled=false` for a second install, and give each install its own `ambassadorId`.

Legacy getambassador.io/v2 resources need Emissary's conversion webhook, which is not
part of this chart. Its image is published as `ghcr.io/quenchworks/images/emissary-apiext`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/emissary \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/emissary --owner quenchworks
```

## Values

| Key | Default | Notes |
|---|---|---|
| `crds.enabled` | `true` | Install the 14 getambassador.io CRDs. |
| `service.type` | `LoadBalancer` | Ports `httpPort` 80 and `httpsPort` 443, to container ports 8080 and 8443. |
| `replicaCount` | `1` | Gateways scale horizontally. |
| `singleNamespace` | `false` | Watch only the release namespace. |
| `ambassadorId` | `""` | Serve only resources whose `ambassador_id` lists this value. |
| `rbac.clusterRules` | read Services/Secrets/Endpoints/Ingresses, write getambassador.io and status | |
| `networkPolicy.enabled` | `false` | A gateway takes traffic from anywhere. |

Diagnostics are on the `-admin` Service, port 8877 (`/ambassador/v0/diag/`). The common
pod knobs from quench-common (`resources`, `nodeSelector`, `affinity`, `tolerations`,
`extraEnvVars`, `extraVolumes`, `sidecars`, probe overrides, security contexts) work as
in every Quenchworks chart.

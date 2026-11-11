# Quenchworks Skipper

Hardened [Skipper](https://github.com/zalando/skipper), Zalando's HTTP router and reverse proxy.
In this chart it runs as a Kubernetes ingress controller: it routes Ingress resources of its
IngressClass through Skipper's filter chain (path and header rewrites, rate limits, auth,
redirects), and it can serve extra routes written in eskip.

The image is built from the upstream release tag (skipper, eskip and routesrv as static Go
binaries), runs as nonroot uid 1001, is CVE-gated (the build fails on any fixable CVE), and is
cosign-signed and pinned by digest.

## Install

```bash
helm install edge oci://ghcr.io/quenchworks/charts/skipper --set service.type=LoadBalancer
kubectl create ingress web --class=skipper --rule='app.example.com/*=web:80'
```

An Ingress picks Skipper with `spec.ingressClassName: skipper`. Skipper filters can be added per
Ingress with the `zalando.org/skipper-filter` annotation, e.g. `setResponseHeader("X-Frame-Options", "DENY")`.

Routes that do not come from an Ingress go in `routes` (eskip):

```yaml
routes: |
  health: Path("/ping") -> inlineContent("pong") -> <shunt>;
  legacy: PathSubtree("/old") -> redirectTo(301, "https://new.example.com") -> <shunt>
```

With `kubernetes.enabled=false` Skipper serves only those routes and gets no RBAC.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/skipper \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/skipper@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/skipper` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `replicaCount` | `1` | Stateless; scale freely. |
| `kubernetes.enabled` | `true` | Ingress controller mode (read-only ClusterRole). |
| `kubernetes.ingressClass` | `skipper` | IngressClass this release creates and serves. |
| `kubernetes.defaultClass` | `false` | Make it the cluster default IngressClass. |
| `kubernetes.routeGroups` | `false` | Read RouteGroups (install the zalando.org CRD separately). |
| `routes` | `""` | eskip routes served next to the Ingress routes. |
| `extraArgs` | `[]` | Extra skipper flags, e.g. `-enable-ratelimits`. |
| `tls.enabled` | `false` | HTTPS on the proxy listener with the chart's certificate. |
| `service.type` / `port` / `httpsPort` | `ClusterIP` / `80` / `443` | |
| `service.externalTrafficPolicy` | `""` | `Local` keeps client source addresses. |
| `networkPolicy.enabled` / `allowExternal` | `true` / `true` | Ingress to the proxy and metrics ports. |
| `resources` | 100m / 128Mi requests, 2 CPU / 512Mi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **Read-only cluster access.** The ClusterRole lists and gets ingresses, ingressclasses,
  services, endpoints, endpointslices, pods and namespaces; nothing is written.
- **Probes** use `/metrics` on the support listener (9911), which answers in every mode.
- **A routes change rolls the pods**: eskip routes are a flag, read at start.
- **TLS** terminates on Skipper itself (`-tls-cert` / `-tls-key` from `/tls`).

Skipper is Apache-2.0 licensed (the pathmux subdirectory is MIT).

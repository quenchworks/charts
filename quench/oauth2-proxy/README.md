# Quenchworks oauth2-proxy

Hardened [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) — a reverse
proxy and static file server that puts OAuth2/OIDC authentication in front of
upstream services — on a minimal, nonroot, 0-CVE image, built from source and
pinned by digest. It runs as a stateless Deployment on a read-only root filesystem
with all capabilities dropped. The image is cosign-signed (keyless / Sigstore) and
the chart pins it by the signed digest, never a tag.

## Install

oauth2-proxy will not start without a complete config, so supply at least a
provider, client id/secret and a cookie secret:

```bash
helm install auth oci://ghcr.io/quenchworks/charts/oauth2-proxy \
  --set config.provider=google \
  --set config.clientID=<id> \
  --set config.clientSecret=<secret> \
  --set config.cookieSecret=<16/24/32-byte secret> \
  --set config.emailDomain='example.com'
```

The proxy runs nonroot and serves the auth/proxy API on container port 4180; the
Service exposes it on the same port. Check health over a port-forward:

```bash
kubectl port-forward svc/auth-oauth2-proxy 4180:4180
curl http://127.0.0.1:4180/ping
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/oauth2-proxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/oauth2-proxy --owner quenchworks`.

## Values

| Key                           | Default                                   | Notes                                                                                                                        |
| ----------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/oauth2-proxy` |                                                                                                                              |
| `image.digest`                | (CI-written)                              | Required. Charts pin by digest, never a tag.                                                                                 |
| `image.pullPolicy`            | `IfNotPresent`                            | `Always`, `IfNotPresent`, or `Never`.                                                                                        |
| `nameOverride`                | `""`                                      | Override the chart name in resource names.                                                                                   |
| `replicaCount`                | `1`                                       | Stateless Deployment (ignored when autoscaling is on).                                                                       |
| `config.provider`             | `""`                                      | OAuth/OIDC provider (`google`, `github`, `oidc`, `azure`, `keycloak-oidc`, ...).                                             |
| `config.clientID`             | `""`                                      | OAuth client id issued by the provider.                                                                                      |
| `config.clientSecret`         | `""`                                      | OAuth client secret issued by the provider.                                                                                  |
| `config.cookieSecret`         | `""`                                      | Cookie signing secret. MUST be 16, 24 or 32 bytes (raw or base64).                                                           |
| `config.emailDomain`          | `"*"`                                     | Allowed email domains (`*` = any).                                                                                           |
| `config.upstream`             | `"static://200"`                          | Upstream to proxy to (`static://200` = 200 with no backend, for forward-auth).                                               |
| `config.extraArgs`            | `[]`                                      | Extra flags appended verbatim to the command.                                                                                |
| `resources.requests`          | `cpu 50m / mem 64Mi`                      |                                                                                                                              |
| `resources.limits`            | `cpu 500m / mem 256Mi`                    |                                                                                                                              |
| `service.type`                | `ClusterIP`                               | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                                                  |
| `service.port`                | `4180`                                    | Proxy/auth API port.                                                                                                         |
| `autoscaling.enabled`         | `false`                                   | HPA on CPU.                                                                                                                  |
| `autoscaling.minReplicas`     | `1`                                       |                                                                                                                              |
| `autoscaling.maxReplicas`     | `5`                                       |                                                                                                                              |
| `serviceAccount.create`       | `true`                                    | Token automount is off.                                                                                                      |
| `serviceAccount.name`         | `""`                                      | Use an existing ServiceAccount if set.                                                                                       |
| `rbac.create`                 | `false`                                   | Minimal Role/RoleBinding.                                                                                                    |
| `networkPolicy.enabled`       | `true`                                    | Restricts ingress.                                                                                                           |
| `networkPolicy.allowExternal` | `true`                                    | The proxy is usually consulted across the cluster (forward-auth, ingress); set `false` to restrict to the release namespace. |
| `podDisruptionBudget.enabled` | `true`                                    | `minAvailable: 1`.                                                                                                           |
| `ingress.enabled`             | `false`                                   | Create an Ingress for this chart. HTTP only.                                                                                 |
| `ingress.className`           | `""`                                      | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                                             |
| `ingress.annotations`         | `{}`                                      | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).                                               |
| `ingress.servicePort`         | `null`                                    | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.                                           |
| `ingress.hosts`               | `[]`                                      | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.                                    |
| `ingress.tls`                 | `[]`                                      | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.                                         |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs the oauth2-proxy binary listening on `0.0.0.0:4180`
behind a ClusterIP Service on the same port. The `config` block is rendered into
the container args, so oauth2-proxy boots with a provider, client id/secret,
cookie secret, upstream and email domain already set; `config.extraArgs` are
appended verbatim after that. Liveness and readiness both hit `GET /ping`
(HTTP 200) once the server is up. Because the proxy holds no server-side state,
the workload scales horizontally — enable `autoscaling` (HPA on CPU) or raise
`replicaCount`. The container runs nonroot on a read-only root filesystem with all
capabilities dropped.

The `cookieSecret` MUST be 16, 24 or 32 bytes (raw or base64) or oauth2-proxy
refuses to boot.

## Configuration examples

Generic OIDC provider fronting an internal app, with secrets kept out of band:

```yaml
config:
  provider: oidc
  clientID: my-app
  emailDomain: example.com
  upstream: http://my-app.default.svc.cluster.local:8080
  extraArgs:
    - "--oidc-issuer-url=https://idp.example.com/realms/main"
    - "--redirect-url=https://app.example.com/oauth2/callback"
# supply clientSecret / cookieSecret via a Secret rather than committing them:
extraEnvVars:
  - name: OAUTH2_PROXY_CLIENT_SECRET
    valueFrom: { secretKeyRef: { name: oauth2-creds, key: client-secret } }
  - name: OAUTH2_PROXY_COOKIE_SECRET
    valueFrom: { secretKeyRef: { name: oauth2-creds, key: cookie-secret } }
```

For production, manage `clientSecret` / `cookieSecret` out of band (via
`extraEnvVars` / `extraEnvVarsSecret`, as above) rather than committing them to
values.

## Uninstall

```bash
helm uninstall auth
```

Nothing persists — the workload is stateless and holds no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on
a read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. oauth2-proxy is itself the trust boundary for the services behind it —
give it real OAuth/OIDC credentials and a strong cookie secret before exposing any
upstream through it.

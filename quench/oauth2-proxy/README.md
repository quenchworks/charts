# Quenchworks oauth2-proxy

Hardened [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) on a
minimal, nonroot, 0-CVE image, built from source and pinned by digest.

## Install

oauth2-proxy will not start without a complete config, so supply at least a
provider, client id/secret and a cookie secret:

```sh
helm install auth oci://ghcr.io/quenchworks/charts/oauth2-proxy \
  --set config.provider=google \
  --set config.clientID=<id> \
  --set config.clientSecret=<secret> \
  --set config.cookieSecret=<16/24/32-byte secret> \
  --set config.emailDomain='example.com'
```

The proxy runs nonroot and serves the auth/proxy API on container port 4180; the
Service exposes it on the same port. Check health over a port-forward:

```sh
kubectl port-forward svc/auth-oauth2-proxy 4180:4180
curl http://127.0.0.1:4180/ping
```

## Configuration

oauth2-proxy listens on `0.0.0.0:4180` and serves `/ping` (HTTP 200) once the
server is up. The chart renders the `config` block into the container args. The
`cookieSecret` MUST be 16, 24 or 32 bytes (raw or base64) or oauth2-proxy refuses
to boot. For production, manage `clientSecret` / `cookieSecret` out of band (e.g.
via `extraEnvVars` / `extraEnvVarsSecret`) rather than committing them to values.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/oauth2-proxy` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment |
| `config.provider` | `""` | OAuth/OIDC provider (google, github, oidc, ...) |
| `config.clientID` | `""` | OAuth client id |
| `config.clientSecret` | `""` | OAuth client secret |
| `config.cookieSecret` | `""` | cookie signing secret, 16/24/32 bytes |
| `config.emailDomain` | `"*"` | allowed email domains (`*` = any) |
| `config.upstream` | `"static://200"` | upstream to proxy to |
| `config.extraArgs` | `[]` | extra flags appended to the command |
| `service.type` | `ClusterIP` | |
| `service.port` | `4180` | proxy/auth API |

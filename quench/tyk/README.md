# Quenchworks tyk

Hardened [Tyk Gateway](https://tyk.io/) (open-source) on a minimal, nonroot,
0-CVE image pinned by digest. Tyk Gateway is stateless (all runtime state lives
in Redis), so it runs as a plain Deployment. This chart ships a **bundled Redis
by default** for a self-contained install, and also supports bringing your own
external Redis.

## Install

Self-contained (bundled Redis):

```bash
helm install my-tyk oci://ghcr.io/quenchworks/charts/tyk
```

Then port-forward and hit the health endpoint:

```bash
kubectl port-forward svc/my-tyk-tyk 8080:80
curl http://127.0.0.1:8080/hello   # -> 200 (JSON status)
```

The gateway control-API secret (used as the `X-Tyk-Authorization` header) is
stored in the release Secret:

```bash
kubectl get secret my-tyk-tyk -o jsonpath='{.data.api-secret}' | base64 -d ; echo
```

> **Rotate the secrets before production.** Set a strong `gateway.secret` /
> `gateway.nodeSecret` (or `gateway.existingSecret`) and a strong
> `redis.auth.password` (shared with the gateway's `storage.password`), or use
> external Redis.

## Configuration

The gateway is configured by a `tyk.conf` (JSON) rendered into a ConfigMap and
mounted read-only at `/etc/tyk/tyk.conf` (`--conf=/etc/tyk/tyk.conf`). Only
non-secret settings live there; the control-API secret, `node_secret` and the
Redis password are injected at runtime via `TYK_GW_*` environment variables from
a Secret (they take precedence over the file), so no credentials are ever written
to the ConfigMap.

Add or override any `tyk.conf` key without templating the whole file:

```yaml
extraConfig:
  log_level: debug
  enable_jsvm: true
```

Publish an API by placing its definition JSON into the gateway's `app_path`
(`/opt/tyk-gateway/apps`, an `emptyDir` by default; supply your own via
`extraVolumes`/`extraVolumeMounts`) and hot-reloading:

```bash
curl -H "X-Tyk-Authorization: <secret>" http://127.0.0.1:8080/tyk/reload/group
```

## Redis modes

**Bundled Redis (default).** `redis.enabled=true` pulls QuenchWorks' own hardened
`redis` subchart. `tyk.conf` `storage.*` points at the subchart's `<release>-redis`
Service (port 6379). The Redis password is shared between the subchart and the
gateway, so both read the same `redis.auth.password`.

**External Redis.** Disable the subchart and point at your own instance:

```yaml
redis:
  enabled: false
externalRedis:
  host: my-redis.data.svc.cluster.local
  port: 6379
  password: change-me
  database: 0
  enableCluster: false
  useSSL: false
```

Or supply the password via a Secret:

```yaml
redis:
  enabled: false
externalRedis:
  host: my-redis.data.svc.cluster.local
  existingSecret: my-redis-secret
  existingSecretPasswordKey: redis-password
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tyk \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/tyk \
  --owner quenchworks
```

## Values

| Key                           | Default                          | Notes                                                                                     |
| ----------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------- | ----------- |
| `image.repository`            | `ghcr.io/quenchworks/images/tyk` |                                                                                           |
| `image.digest`                | (CI-written)                     | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                              | Stateless; can be scaled out.                                                             |
| `containerPort`               | `8080`                           | Port the gateway binds (nonroot). Wired to `listen_port`.                                 |
| `service.port`                | `80`                             | Service port, forwards to the container's `http` port.                                    |
| `gateway.secret`              | `""`                             | Control-API secret. Random+persisted if empty.                                            |
| `gateway.nodeSecret`          | `""`                             | `node_secret`. Random+persisted if empty.                                                 |
| `gateway.existingSecret`      | `""`                             | Supply both secrets via your own Secret.                                                  |
| `extraConfig`                 | `{}`                             | Extra `tyk.conf` keys merged over the baseline (your keys win).                           |
| `redis.enabled`               | `true`                           | Bundled hardened Redis subchart.                                                          |
| `redis.auth.enabled`          | `true`                           |                                                                                           |
| `redis.auth.password`         | `tyk-redis`                      | **Shared with the gateway's `storage.password`; override for production.**                |
| `externalRedis.*`             | (unset)                          | Used when `redis.enabled=false`.                                                          |
| `serviceAccount.create`       | `true`                           | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                          | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                           | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                           | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                          | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                             | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                             | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                           | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                             | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                             | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      | ## Security |

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped; only `emptyDir` mounts for `/tmp` and the gateway `app_path` are
writable, plus the read-only `tyk.conf` ConfigMap. The gateway serves `GET /hello`
(returns `200` with a JSON status), used for both liveness and readiness probes.
The control-API secret, `node_secret` and the Redis password are kept in a
Kubernetes Secret.

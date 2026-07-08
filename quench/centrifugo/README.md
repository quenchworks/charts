# Quenchworks Centrifugo

Hardened [Centrifugo](https://github.com/centrifugal/centrifugo) on a minimal,
nonroot, 0-CVE image, pinned by digest. Centrifugo is a scalable real-time
messaging server speaking WebSocket, SSE, HTTP-streaming and GRPC, with JWT auth,
an admin UI, and a server HTTP API.

## Install

```sh
helm install messaging oci://ghcr.io/quenchworks/charts/centrifugo
```

The server runs nonroot with the in-memory engine and serves the client endpoints,
the admin UI, the HTTP API and `/health` on container port 8000; the Service
exposes it on the same port. Check health over a port-forward:

```sh
kubectl port-forward svc/messaging-centrifugo 8000:8000
curl http://127.0.0.1:8000/health
```

## Engine (stateless vs scale-out)

By default the chart runs a single-replica `Deployment` with the **in-memory**
engine: fully stateless, no Redis required. Presence/history/PUB-SUB are not shared
across pods, so keep `replicaCount: 1`.

For horizontal scale-out switch to the **Redis** engine and point it at your Redis:

```yaml
engine:
  type: redis
replicaCount: 3
extraEnvVars:
  - name: CENTRIFUGO_ENGINE_REDIS_ADDRESS
    value: "redis://redis-master.default.svc.cluster.local:6379"
```

## Secrets

Centrifugo needs a token HMAC secret (verifies client JWTs), an HTTP API key, and —
for the admin UI — an admin password and admin secret. The chart provisions all
four in a managed Secret: each is **generated if left empty** and **preserved
across `helm upgrade`** via a lookup, so upgrades never rotate live credentials.
Set any `secrets.*` value explicitly to control it; rotate in production by
updating the value and upgrading. Point `secrets.existingSecret` at your own Secret
(keys mapped via `secrets.keys.*`) to own them yourself.

Read the generated admin password / API key:

```sh
kubectl get secret messaging-centrifugo -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl get secret messaging-centrifugo -o jsonpath='{.data.http-api-key}'   | base64 -d; echo
```

Call the HTTP API:

```sh
curl -H "X-API-Key: $API_KEY" -X POST http://127.0.0.1:8000/api/info
```

## Configuration

Everything is driven by `CENTRIFUGO_*` environment variables (see
`centrifugo defaultenv` for the full list). `extraEnvVars` is the seam for any
setting not surfaced as a value (TLS, proxies, channel namespaces, Redis tuning).

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/centrifugo` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | stateless Deployment (memory engine) |
| `engine.type` | `memory` | `memory` (single node) or `redis` (scale-out) |
| `admin.enabled` | `true` | admin web UI at `/` |
| `secrets.tokenHmacSecretKey` | `""` | generated if empty; `CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY` |
| `secrets.apiKey` | `""` | generated if empty; `CENTRIFUGO_HTTP_API_KEY` |
| `secrets.adminPassword` | `""` | generated if empty; `CENTRIFUGO_ADMIN_PASSWORD` |
| `secrets.adminSecret` | `""` | generated if empty; `CENTRIFUGO_ADMIN_SECRET` |
| `secrets.existingSecret` | `""` | bring your own Secret (keys via `secrets.keys.*`) |
| `allowedOrigins` | `[]` | `CENTRIFUGO_CLIENT_ALLOWED_ORIGINS` (space-joined) |
| `service.type` | `ClusterIP` | |
| `service.port` | `8000` | client endpoints, admin UI, API, `/health` |

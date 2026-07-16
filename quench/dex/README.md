# Quenchworks Dex

Hardened [Dex](https://github.com/dexidp/dex) (the CNCF OpenID Connect identity
provider and federated SSO gateway) on a minimal, nonroot, 0-CVE image, pinned by
digest and cosign-signed.

## Install

```sh
helm install dex oci://ghcr.io/quenchworks/charts/dex
```

Dex runs nonroot on a read-only root filesystem. The image entrypoint is
`dex serve`; this chart starts it as `dex serve /etc/dex/config.yaml`, rendering
`config.yaml` into a ConfigMap and mounting it at `/etc/dex/config.yaml`.

## Ports

| Port | Name | Purpose |
|------|------|---------|
| `5556` | `http` | OIDC issuer + login UI |
| `5557` | `grpc` | gRPC API |
| `5558` | `telemetry` | health (`/healthz`) + Prometheus metrics |

Liveness/readiness probe `GET /healthz` on the telemetry port (`5558`).

Check the discovery document over a port-forward:

```sh
kubectl port-forward svc/dex-dex 5556:5556 5558:5558
curl http://127.0.0.1:5558/healthz
curl http://127.0.0.1:5556/dex/.well-known/openid-configuration
```

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/dex \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/dex --owner quenchworks`.

## Configuration

Dex is configured entirely through a single YAML config file. Set `config.yaml`
to a [Dex configuration](https://dexidp.io/docs/configuration/) (issuer, storage,
web, grpc, telemetry, connectors, staticClients, staticPasswords); it is written
to a ConfigMap and mounted at `config.yaml`. Point `config.existingConfigMap` at
an externally-managed ConfigMap (key `config.yaml`) to manage the config out of
band (e.g. to keep connector secrets separate); when set it wins over
`config.yaml`.

### Production note: default storage is in-memory

The default config uses `storage: { type: memory }` so the chart boots on a
read-only root filesystem with no volume. In-memory storage loses all clients,
refresh tokens, and signing keys on every restart and cannot be scaled out, so it
is for evaluation only. The default also ships a static example user
(`admin@example.com` / `password`) and binds the issuer to `0.0.0.0`.

For production:

- Set a stable, externally reachable issuer URL (e.g. `https://dex.example.com`).
- Switch storage to a shared backend: `postgres`, `etcd`, or `kubernetes`
  (CRDs). For `sqlite3`, add a writable volume via `extraVolumes`/`extraVolumeMounts`
  and point `storage.config.file` at it (read-only rootfs blocks writes elsewhere).
- Replace `staticPasswords` with a real connector (LDAP, SAML, OIDC, GitHub,
  Google, etc.).

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/dex` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | safe only with shared storage |
| `config.yaml` | in-memory example | inline Dex config (rendered + mounted) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `config.yaml`, wins) |
| `configMountPath` | `/etc/dex/config.yaml` | where the config is mounted |
| `command` / `args` | `dex` / `serve <config>` | container command override |
| `service.type` | `ClusterIP` | |
| `service.ports.http` | `5556` | OIDC issuer + UI |
| `service.ports.grpc` | `5557` | gRPC API |
| `service.ports.telemetry` | `5558` | health + metrics |

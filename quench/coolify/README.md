# Quenchworks Coolify

Hardened [Coolify](https://coolify.io/), the self-hostable PaaS (an open-source
Heroku/Netlify/Vercel alternative), on minimal, nonroot, 0-CVE images pinned by
digest. This umbrella chart deploys the Coolify control plane into Kubernetes and
wires it to bundled Quenchworks PostgreSQL 15 and Redis.

Two control-plane workloads run in the cluster:

- `coolify-app`, the PHP/Laravel core: php-fpm plus Quenchworks nginx (UI + API on
  `:8080`, health at `GET /healthcheck`), Horizon (queue workers) and the Laravel
  scheduler, all under `supervisord`. Runs as uid `9999` on a read-only root
  filesystem. On first boot it runs DB migrations, the seeder and `app:init`.
- `coolify-realtime`, soketi (a Pusher-compatible WebSocket server on `:6001` the UI
  subscribes to) plus the node-pty terminal bridge (`:6002`). Runs as uid `1001`. Both
  endpoints expose `GET /ready`.

## Architecture: Coolify manages external Docker hosts over SSH

Coolify is not a Kubernetes-native workload orchestrator. It is a control plane
that manages external Docker hosts over SSH. You add a server in the UI, Coolify
stores an SSH keypair (under the app's persistent `storage/app/ssh`), connects to that
host, and from then on it builds and runs your applications on that host's Docker
daemon, not in this Kubernetes cluster.

Consequently:

- This chart deploys only the control plane (app + realtime + Postgres + Redis).
- The build/deploy tier (the `coolify-helper` build engine and the per-server
  proxy) runs on the managed Docker hosts, pulled and run there by Coolify over
  SSH. The `coolify-helper` image is therefore referenced in the chart's
  `artifacthub.io/images` (so it is discoverable and scanned) but is deliberately
  not a Deployment here.
- Honesty note: the helper/proxy tier on those managed hosts is privileged by
  design, since it drives the host's Docker daemon. That privilege lives on the external
  hosts you connect, never in this cluster. The control plane deployed by this chart is
  fully hardened (nonroot, read-only rootfs, dropped capabilities, no privilege
  escalation).

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL 15 + Redis with deterministic creds
helm install ops oci://ghcr.io/quenchworks/charts/coolify
```

The bundled `postgresql` subchart is reused for PostgreSQL 15 by overriding its image
to the `postgresql-15` digest (Coolify pins pg15-specific migrations). The standard
postgres entrypoint only creates the application database when the username and database
differ, so the defaults use `coolifyadmin` / `coolify`.

## Connect

```bash
# admin password (generated if you do not set app.rootUser.password)
kubectl get secret ops-coolify -o jsonpath="{.data.root-user-password}" | base64 -d ; echo

# reach the UI / API
kubectl port-forward svc/ops-coolify-app 8080:8080
# open http://127.0.0.1:8080/  and log in with app.rootUser.email
curl -fsS http://127.0.0.1:8080/healthcheck   # -> OK
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/coolify \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/coolify --owner quenchworks`.
The `coolify-realtime` and `coolify-helper` images verify the same way (swap the
repository).

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `app.replicaCount` | `1` | coolify-app replicas |
| `app.appKey` / `app.appId` | generated | Laravel `APP_KEY` / `APP_ID` (persisted across upgrades, never rotated) |
| `app.url` | app Service | Public `APP_URL` (defaults to ingress host, else the in-cluster Service) |
| `app.rootUser.email` / `.password` | `admin@example.com` / generated | Initial admin seeded by `app:init` |
| `app.horizonEnabled` / `app.schedulerEnabled` | `true` | Background workers |
| `app.persistence.enabled` / `.size` | `true` / `1Gi` | Persist `storage/` (SSH keys to managed hosts) |
| `realtime.replicaCount` | `1` | coolify-realtime replicas |
| `pusher.appId` / `.appKey` / `.appSecret` | generated | Shared Pusher/soketi credentials |
| `postgresql.enabled` | `true` | Bundle PostgreSQL 15 (image overridden to `postgresql-15`) |
| `postgresql.auth.{username,password,database}` | `coolifyadmin` / `coolify` / `coolify` | Bundled DB creds (username ≠ database required) |
| `externalDatabase.*` | — | Used when `postgresql.enabled=false` (must be PostgreSQL 15) |
| `redis.enabled` | `true` | Bundle Redis |
| `redis.auth.password` | `coolify-redis` | Bundled Redis password |
| `externalRedis.*` | — | Used when `redis.enabled=false` |
| `ingress.enabled` | `false` | Optional Traefik Ingress to the app Service |

### `.env` handling (read-only rootfs)

The app image ships `/var/www/html/.env` as a symlink to `/tmp/coolify.env` (a
writable tmpfs), seeded from `.env.production` on boot. This chart instead renders a
complete `.env` into the managed Secret and mounts it read-only at
`/var/www/html/.env` (a `subPath` mount that replaces the symlink: a real `.env`
mounted over that path wins). All credentials (`APP_KEY`, DB/Redis passwords, Pusher
creds) come from the single deterministic Secret, generated once and persisted across
upgrades via `lookup` so encrypted DB rows stay decryptable.

## Security

- All images are pinned by digest (never a tag), cosign-signed (keyless / Sigstore)
  and ship SBOM + SLSA provenance attestations.
- Hardened pod/container security contexts (nonroot, read-only root filesystem, all
  capabilities dropped, no privilege escalation, `RuntimeDefault` seccomp).
- A default `NetworkPolicy` (egress is left open because the control plane must reach
  the external Docker hosts over SSH and pull images/git remotes).

Chart/tooling are MIT; Coolify itself is Apache-2.0 (reflected in
`artifacthub.io/license`).

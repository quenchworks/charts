# Quenchworks Gitea

Hardened [Gitea](https://about.gitea.com/), a lightweight self-hosted Git service,
on a minimal, nonroot, 0-CVE image pinned by digest. The Go backend is built from
the official release source (the prebuilt Vue web assets ship inside it, so no Node
build), and runs on a read-only root filesystem as a StatefulSet. The web UI + API +
git-over-HTTP are on port `3000`; git-over-SSH is on the unprivileged port `2222`.

Gitea keeps its repository data on disk (repos, LFS, attachments, the host SSH key);
all relational state lives in **PostgreSQL**. This chart bundles the Quenchworks
PostgreSQL chart by default and can also point at an external database.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install git oci://ghcr.io/quenchworks/charts/gitea
```

An admin user is created idempotently on first boot. Its password is stored in a
Secret (generated if you do not supply one).

## Connect

```bash
# admin password
kubectl get secret git-gitea -o jsonpath="{.data.admin-password}" | base64 -d

# reach the web UI
kubectl port-forward svc/git-gitea 3000:3000
# open http://127.0.0.1:3000/  (user: gitea_admin)
```

Authenticate the admin via the API (basic auth):

```bash
curl -fsS -u "gitea_admin:<password>" http://127.0.0.1:3000/api/v1/user
# -> JSON describing the admin user
```

Health check:

```bash
curl -fsS http://127.0.0.1:3000/api/healthz
# -> {"status":"pass", ...}
```

## Clone

```bash
# over HTTP
git clone http://127.0.0.1:3000/gitea_admin/<repo>.git

# over SSH (port 2222, since uid 1001 cannot bind the privileged port 22)
git clone ssh://git@<host>:2222/gitea_admin/<repo>.git
```

## Database

### Bundled (default)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart. Both Gitea and
PostgreSQL share the deterministic credentials under `postgresql.auth`, so the DB
connection is derived from the subchart's service automatically:

```yaml
postgresql:
  enabled: true
  auth:
    # username and database MUST differ; the bundled PG seeds the app database only
    # when it differs from both "postgres" and the superuser name.
    username: gitea
    password: gitea
    database: giteadb
```

### External

Set `postgresql.enabled=false` and point `externalDatabase` at any reachable
PostgreSQL:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.com
  port: 5432
  database: giteadb
  user: gitea
  password: ""            # or use existingSecret + existingSecretPasswordKey
```

## Persistence

`persistence.enabled=true` (default) provisions a PVC for `/data` (repositories, LFS,
attachments, the host SSH key) via a `volumeClaimTemplate`. Set `persistence.enabled=false`
for an ephemeral `emptyDir` (the CI gate uses this), or bind `persistence.existingClaim`.

## Ingress

Off by default. `ingress.enabled=true` plus at least one host publishes the HTTP UI/API
through an Ingress; the backend port is resolved from the chart's own Service, so only
the host is required:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: gitea.example.com     # a host with no `paths` gets one "/" Prefix path
  tls:
    - hosts: [gitea.example.com]
      secretName: gitea-tls
```

`ingress.annotations` passes controller annotations through, and `ingress.servicePort`
overrides the resolved port. Note this fronts HTTP only: **git over SSH is a TCP
protocol and cannot traverse an Ingress** -- expose port 22 with
`service.type=LoadBalancer` or your controller's TCP passthrough.

## Hardening

- Runs as nonroot uid 1001 with a read-only root filesystem and all capabilities
  dropped (via `quench-common` defaults). Writable mounts: `/data`, `/etc/gitea`, `/tmp`.
- `INSTALL_LOCK=true`: the web installer is disabled; the chart configures everything.
- A generated `SECRET_KEY` + `INTERNAL_TOKEN` are stored in the managed Secret and
  preserved across upgrades (lookup-persisted).
- Open registration is disabled by default (`server.disableRegistration=true`).
- A `NetworkPolicy` and `PodDisruptionBudget` are enabled by default.

Set the public URL so Gitea builds correct clone/webhook/OAuth links:

```yaml
server:
  rootUrl: https://git.example.com/
  domain: git.example.com
```

The image is pinned by digest and signed (cosign keyless). Verify it:

```bash
cosign verify ghcr.io/quenchworks/images/gitea \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/gitea --owner quenchworks`.

# Quenchworks Adminer

Hardened [Adminer](https://github.com/vrana/adminer), vrana's single-file database
manager — a web UI to browse, query and administer SQL databases — on a minimal,
nonroot, 0-CVE PHP image, cosign-signed and pinned by digest. Runs as a stateless
Deployment behind a ClusterIP Service, serving the UI on port `8080`.

> Adminer has **no authentication of its own**. It shows a login form and connects to
> whatever host and credentials the visitor types, so anyone who reaches it can attempt
> a login against every database the pod can route to. The chart ships closed —
> namespace-only NetworkPolicy, no Ingress — and exposing it is a deliberate act.

## Install

```bash
helm install adminer oci://ghcr.io/quenchworks/charts/adminer
```

```bash
kubectl port-forward svc/adminer 8080:8080
# browse http://127.0.0.1:8080/
```

On the login page pick the system and enter the in-cluster address of the database:

```
System:   PostgreSQL
Server:   my-postgresql.default.svc.cluster.local:5432
Username: postgres
```

## Driver support

Adminer's login page lists every system it knows about, but only the drivers compiled
into the PHP runtime can actually connect. In the currently pinned image:

| System              | Status                                                                   |
| ------------------- | ------------------------------------------------------------------------ |
| PostgreSQL          | works (`pdo_pgsql`, `pgsql`)                                             |
| SQLite / SQLite 3   | works (`pdo_sqlite`)                                                     |
| MySQL / MariaDB     | **not usable yet** — see below                                           |

MySQL/MariaDB logins fail with *"None of the supported PHP extensions (MySQLi, MySQL,
PDO_MySQL) are available."* The image's `mysqli.so` and `pdo_mysql.so` fail to load at
PHP startup with `undefined symbol: mysqlnd_global_stats`, because the mysqlnd driver
library is not installed alongside them. It is an image-side gap, not a chart setting,
and there is nothing to configure here: once a rebuilt image ships the missing package
CI re-pins this chart's digest and MySQL/MariaDB starts working with no chart change.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/adminer \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/adminer --owner quenchworks`.

## Values

| Key                           | Default                              | Notes                                                                                             |
| ----------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/adminer` |                                                                                                   |
| `image.digest`                | (CI-written)                          | Required. Charts pin by digest, never a tag.                                                      |
| `image.pullPolicy`            | `IfNotPresent`                        |                                                                                                   |
| `nameOverride`                | `""`                                  | Override the chart name in resource names.                                                        |
| `replicaCount`                | `1`                                   | Stateless Deployment.                                                                             |
| `resources.requests`          | `cpu 20m / mem 64Mi`                  |                                                                                                   |
| `resources.limits`            | `cpu 500m / mem 256Mi`                |                                                                                                   |
| `service.type`                | `ClusterIP`                           | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                       |
| `service.port`                | `8080`                                | The UI. Nonroot cannot bind a privileged port, so the container listens on 8080.                  |
| `tmpVolume.sizeLimit`         | `64Mi`                                | Size of the in-memory `/tmp` for PHP session/upload scratch. Raise it to import large dumps.      |
| `serviceAccount.create`       | `true`                                | Token automount is off — Adminer never calls the API server.                                      |
| `serviceAccount.name`         | `""`                                  | Use an existing ServiceAccount.                                                                   |
| `rbac.create`                 | `false`                               | Nothing to grant.                                                                                 |
| `networkPolicy.enabled`       | `true`                                | Restricts ingress to the UI port.                                                                 |
| `networkPolicy.allowExternal` | `false`                               | Same-namespace only by default. Deliberate: see the warning above.                                |
| `podDisruptionBudget.enabled` | `false`                               | Off: a single-replica admin UI is not worth blocking a node drain.                                |
| `ingress.enabled`             | `false`                               | Create an Ingress. HTTP only; put authentication and TLS in front.                                |
| `ingress.className`           | `""`                                  | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.                  |
| `ingress.annotations`         | `{}`                                  | Controller annotations (auth-url, body size, cert-manager issuer, ...).                           |
| `ingress.servicePort`         | `null`                                | Backend port. Unset resolves `service.port`.                                                      |
| `ingress.hosts`               | `[]`                                  | e.g. `[{host: adminer.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path.     |
| `ingress.tls`                 | `[]`                                  | Standard Ingress TLS list.                                                                        |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

Adminer is one PHP script. There is no application state, no configuration file and
no database of its own: it opens a connection to whichever server the operator logs
into and closes it again, so this is a plain stateless Deployment that scales and
restarts freely.

The image's entrypoint is PHP's built-in webserver — `php -S 0.0.0.0:8080 -t
/var/www/html` — with `php` as PID 1, so it reaps and signals correctly and the chart
sets no `command`. Port `8080` rather than `80` because the container runs nonroot
(uid 1001) and cannot bind a privileged port. Liveness and readiness both `httpGet /`,
which returns the login page as soon as the server is listening and needs no database
to answer.

The root filesystem is read-only, so `/tmp` is a small `emptyDir` on `medium: Memory`
— PHP's session and upload scratch. Nothing there is meant to survive a restart;
without the mount, every login attempt fails on a session write.

Egress is deliberately unrestricted: reaching arbitrary database hosts *is* the
application. The trust boundary is therefore ingress-side — the NetworkPolicy, and
whatever authenticates in front of the Ingress.

## Configuration examples

Expose it behind oauth2-proxy on an nginx ingress, with TLS from cert-manager:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/auth-url: https://auth.example.com/oauth2/auth
    nginx.ingress.kubernetes.io/auth-signin: https://auth.example.com/oauth2/start?rd=$scheme://$host$request_uri
  hosts:
    - host: adminer.example.com
  tls:
    - hosts: [adminer.example.com]
      secretName: adminer-tls
```

Let an ops namespace reach the UI while keeping the policy closed to everything else:

```yaml
networkPolicy:
  extraFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ops
```

Import a multi-hundred-megabyte SQL dump through the UI:

```yaml
tmpVolume:
  sizeLimit: 1Gi
resources:
  limits: { cpu: 1, memory: 1536Mi }   # medium: Memory /tmp counts against the pod's memory
```

## Uninstall

```bash
helm uninstall adminer
```

Nothing persists — no PVCs, and the `/tmp` scratch dies with the pod. The databases
Adminer connected to are untouched.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on a
read-only root filesystem with all capabilities dropped, and the image is pinned by
digest.

Treat a running Adminer as a credential-entry surface: it is a general-purpose SQL
client with a web UI, not a read-only dashboard. Prefer installing it into the
namespace whose databases you administer, keep `allowExternal: false`, and uninstall
it when the maintenance window closes rather than leaving it up.

# Nautobot

[Nautobot](https://networktocode.com/nautobot/), the network source of truth and automation platform: IPAM, DCIM,
circuits, Jobs, GraphQL and Git-backed data. It runs on the bundled PostgreSQL and Valkey, with a Celery worker and
beat. The image is built from the release wheel by QuenchWorks, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install nautobot oci://ghcr.io/quenchworks/charts/nautobot
kubectl get secret nautobot -o jsonpath='{.data.admin-password}' | base64 -d
```

An init container runs `nautobot-server post_upgrade` (migrations and housekeeping) and creates the admin user when it
is missing, on every start. The Celery worker and beat run as their own Deployments.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.user`, `.email`, `.password` | `admin`, generated | The first superuser, created when missing. |
| `allowedHosts`, `csrfTrustedOrigins` | `[]` | Extra host names and origins (an Ingress). Service names and localhost are always allowed. |
| `settings` | `{}` | Extra `NAUTOBOT_*` environment settings. |
| `extraConfig` | `""` | Python run after Nautobot's settings: `PLUGINS`, `PLUGINS_CONFIG`, SSO. |
| `secret.existingSecret` | `""` | Secret with `admin-password` and `secret-key`. |
| `postgresql.enabled` / `externalDatabase.*` | bundled | PostgreSQL. |
| `valkey.enabled` / `externalRedis.*` | bundled | Redis for Celery and the cache. |
| `persistence.*` | 5Gi RWO | Media, Git repositories and Jobs. Web and Celery share it: use ReadWriteMany across nodes. |
| `celery.worker`, `celery.beat` | on | Background Jobs and scheduled Jobs. |

Plain HTTP only: the bundled uWSGI (pyuwsgi) is built without TLS. Put an Ingress with TLS in front.

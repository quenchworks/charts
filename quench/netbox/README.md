# NetBox

[NetBox](https://netboxlabs.com/oss/netbox/), the source of truth for network and data-center infrastructure: IPAM,
DCIM, circuits, virtualization, and a REST and GraphQL API. It runs on the bundled PostgreSQL and Valkey. The image is
built from source by QuenchWorks, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install netbox oci://ghcr.io/quenchworks/charts/netbox
kubectl get secret netbox -o jsonpath='{.data.admin-password}' | base64 -d
```

An init container runs the migrations and creates the admin user on every start (both idempotent). The RQ worker runs
as its own Deployment.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.user`, `.email`, `.password` | `admin`, generated | The first superuser, created when missing. |
| `allowedHosts` | `[]` | Extra host names (Ingress hosts). Service names and localhost are always allowed. |
| `extraConfig` | `""` | Python appended to the configuration: `CSRF_TRUSTED_ORIGINS`, SSO (`REMOTE_AUTH_*`, `SOCIAL_AUTH_*`), `PLUGINS`. |
| `secret.existingSecret` | `""` | Secret with `admin-password`, `secret-key`, `api-token-pepper` (50+ characters for each key). |
| `postgresql.enabled` / `externalDatabase.*` | bundled | PostgreSQL. |
| `valkey.enabled` / `externalRedis.*` | bundled | Redis for the task queue and the cache. |
| `persistence.*` | 2Gi RWO | Uploads. Web and worker share it: use ReadWriteMany across nodes. |
| `tls.enabled` | `false` | gunicorn serves HTTPS on 8080 (existing Secret, cert-manager, or a Helm-made CA). |
| `worker.enabled` | `true` | The RQ worker (background jobs, scripts, webhooks). |
| `metrics.enabled` | `false` | Prometheus metrics at `/metrics`. |

The secret key and the API token pepper are generated once and kept on upgrade. Changing the pepper voids every
v2 API token.

# Quenchworks Apprise API

Hardened [Apprise API](https://github.com/caronc/apprise-api): one REST call to send notifications to 100+ services
(email, Slack, Discord, Telegram, ntfy, Matrix, webhooks and more), with configs stored under keys and a web UI. The
image runs upstream's own runtime (nginx, gunicorn, pruner) on Wolfi python as uid 1001 on a read-only root
filesystem; it is CVE-gated at build, cosign-signed and pinned by digest.

The chart turns upstream's authentication on and generates the admin password and the Django `SECRET_KEY` (upstream
ships a fixed default).

## Install

```bash
helm install notify oci://ghcr.io/quenchworks/charts/apprise-api --set configLock=false
P=$(kubectl get secret notify-apprise-api -o jsonpath='{.data.password}' | base64 -d)
kubectl port-forward svc/notify-apprise-api 8000:8000 &
curl -u admin:$P -d 'urls=ntfy://ntfy.example.com/alerts' http://127.0.0.1:8000/add/ops
curl -u admin:$P -d 'body=disk almost full' http://127.0.0.1:8000/notify/ops
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled`, `auth.username` | `true`, `admin` | Upstream's HTTP basic auth on every call |
| `auth.password`, `auth.existingSecret` | generated | The password (and `secret-key`), kept on upgrade |
| `statefulMode` | `simple` | Config storage: `simple`, `hash` or `disabled` |
| `configLock` | `false` | Refuse `/add` and `/del` and hide stored URLs (the admin account is exempt) |
| `strictMode` | `false` | Upstream's strict nginx profile |
| `settings` | `{}` | More upstream variables (`APPRISE_API_ONLY`, `APPRISE_ALLOW_SERVICES`, `APPRISE_BASE_URL`, ...) |
| `persistence.size` | `1Gi` | Stored configs (`/config`) |
| `ingress.*` | off | No TLS listener in the pod: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/apprise-api \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

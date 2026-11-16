# Quenchworks traggo

Hardened [traggo](https://github.com/traggo/server): tag-based time tracking with dashboards, a web UI and a GraphQL
API, on SQLite or PostgreSQL. The image builds the Go server and its React UI from source; it runs as uid 1001 on a
read-only root filesystem and is CVE-gated at build, cosign-signed and pinned by digest.

The chart creates the first admin from a generated Secret (upstream would create admin/admin).

## Install

```bash
helm install timetracking oci://ghcr.io/quenchworks/charts/traggo \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=time.example.com' \
  --set 'ingress.tls[0].hosts[0]=time.example.com' --set 'ingress.tls[0].secretName=time-tls'
kubectl get secret timetracking-traggo -o jsonpath='{.data.password}' | base64 -d   # sign in as admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.username`, `auth.password` | `admin`, generated | The first admin, created on an empty database |
| `auth.existingSecret` | `""` | A Secret with key `password` instead |
| `settings` | `{}` | More `TRAGGO_*` settings (log level, password strength, PostgreSQL) |
| `persistence.size` | `1Gi` | The SQLite database (`/var/lib/traggo`) |
| `ingress.*` | off | traggo has no TLS listener: terminate TLS at the Ingress |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/traggo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

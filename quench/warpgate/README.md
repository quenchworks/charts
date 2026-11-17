# Quenchworks Warpgate

Hardened [Warpgate](https://github.com/warp-tech/warpgate): a bastion (jump host) for SSH, HTTPS, MySQL,
PostgreSQL, Kubernetes, RDP and VNC targets, with single sign-on, per-target access, session recording and
a web UI, and no client agent: users connect with their usual tools. The image is built from source (Rust
through cargo auditable, the web UI with Node), runs as uid 1001 and is CVE-gated at build, cosign-signed and
pinned by digest.

The chart runs one instance with its data on a volume (config, database, SSH keys and recordings). A setup
step creates the configuration and the `admin` user on the first start with a generated password.

## Install

```bash
helm install bastion oci://ghcr.io/quenchworks/charts/warpgate --set externalHost=bastion.example.com
kubectl get secret bastion-warpgate -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/bastion-warpgate 8888:8888   # https://localhost:8888/@warpgate
```

Add targets and users in the admin UI. SSH users connect with `ssh <user>:<target>@bastion.example.com -p 2222`.

## Exposing it

The web UI is HTTPS (self-signed until you install a certificate in the admin UI), so an Ingress needs an
HTTPS backend (`nginx.ingress.kubernetes.io/backend-protocol: HTTPS` is set by default). SSH, MySQL and
PostgreSQL are plain TCP: expose them with `service.type: LoadBalancer`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `externalHost` | `""` | The host users reach Warpgate on (URLs, SSO redirects) |
| `admin.password` / `admin.existingSecret` | generated | The first admin's password |
| `ssh.enabled` | `true` | SSH listener (port 2222) |
| `mysql.enabled` / `postgres.enabled` | `false` | Database protocol listeners |
| `recordSessions` | `true` | Record sessions on the volume |
| `databaseUrl` | SQLite on the volume | A PostgreSQL or MySQL URL instead, read at the first setup |
| `persistence.size` | `5Gi` | The data volume |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/warpgate \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks Beszel

Hardened [Beszel](https://github.com/henrygd/beszel), lightweight server monitoring: a hub
(PocketBase plus a web UI) that collects CPU, memory, disk, network and container stats from small
agents, with history and alerts. One image carries both binaries; it is built from source, runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install mon oci://ghcr.io/quenchworks/charts/beszel --set admin.email=you@example.com
kubectl get secret mon-beszel-admin -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/mon-beszel 8090
```

Beszel creates the PocketBase superuser and an admin user from `admin.email` and the generated
password on its first start, so the hub has no open first-run page.

## Agents on the nodes

The agent runs from the same image (`/usr/bin/beszel-agent`) as an optional DaemonSet with the host
network and host PID. After the first sign-in, open "Add system", put the hub's public key and the
token in a Secret, then:

```bash
kubectl create secret generic beszel-agent --from-literal=key='ssh-ed25519 AAAA...' --from-literal=token='...'
helm upgrade mon oci://ghcr.io/quenchworks/charts/beszel --reuse-values \
  --set agent.enabled=true --set agent.existingSecret=beszel-agent
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.email`, `admin.password` | `admin@example.com`, generated | First superuser and admin, created on the first start |
| `agent.enabled`, `agent.existingSecret` | `false`, `""` | Agent DaemonSet and the Secret with its `key` and `token` |
| `settings` | `{}` | More hub env (`APP_URL`, ...) |
| `persistence.size` | `2Gi` | PocketBase data volume |

## Uploads and CVE-2023-36308

PocketBase thumbnails uploaded images with `disintegration/imaging` 1.6.2, which has no fixed
release for CVE-2023-36308. The image's `golang.org/x/image` rejects the crafted palettes that
trigger it and imaging's palette table is patched at build time; the image's VEX statement records
the evidence.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/beszel \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

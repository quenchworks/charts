# Quenchworks Dozzle

Hardened [Dozzle](https://github.com/amir20/dozzle), a real-time log viewer. This chart runs it in
Kubernetes mode: it streams pod logs through the API with a read-only ClusterRole, with search
and a web UI. The image is one CGO-free Go binary built from source with its UI embedded; it runs
as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install logs oci://ghcr.io/quenchworks/charts/dozzle
kubectl get secret logs-dozzle-auth -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/logs-dozzle 8080
```

Upstream's default is no login at all. This chart turns on simple auth with one user whose
bcrypt hash Helm renders into `users.yml`; the generated password is kept across upgrades.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.enabled`, `auth.username`, `auth.password` | `true`, `admin`, generated | Simple auth with one user |
| `namespaces` | `[]` (all) | Namespaces to watch (`DOZZLE_NAMESPACE`) |
| `enableActions` | `false` | Restart from the UI (deletes the pod; adds `delete` on pods to the role) |
| `settings` | `{}` | More `DOZZLE_*` env |

The image also runs against a Docker socket outside Kubernetes. Its embedded agent key pair is
generated per build, unlike upstream's shared pair, so remote Dozzle agents need matching
certificates mounted.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dozzle \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

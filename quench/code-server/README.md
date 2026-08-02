# Quenchworks code-server

Hardened [code-server](https://github.com/coder/code-server) (VS Code in the
browser) by Coder, on a minimal, nonroot, 0-CVE image built on Wolfi from Coder's
official prebuilt release, cosign-signed and pinned by digest. Runs as a
single-replica Deployment with a persistent workspace and PASSWORD login, serving
the editor on port 8080.

## Install

```bash
helm install ide oci://ghcr.io/quenchworks/charts/code-server
```

Read the generated login password and open the editor over a port-forward:

```bash
kubectl get secret ide-code-server -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward svc/ide-code-server 8080:8080
# browse http://127.0.0.1:8080
```

Set your own password instead:

```bash
helm install ide oci://ghcr.io/quenchworks/charts/code-server \
  --set auth.password='choose-a-strong-one'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/code-server \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/code-server --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/code-server` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `auth.password` | `""` | Login password. Empty = a random 24-char password is generated into the Secret (stable across upgrades). |
| `auth.existingSecret` | `""` | Use your own Secret for the password instead of the generated one. |
| `auth.existingSecretKey` | `password` | Key in `existingSecret` holding the password. |
| `extraArgs` | `[]` | Extra flags appended to the container command. |
| `persistence.enabled` | `true` | Persist `$HOME` (workspace + editor state) on a PVC. `false` = emptyDir. |
| `persistence.size` | `10Gi` | |
| `persistence.mountPath` | `/home/coder` | |
| `persistence.storageClass` | (default) | |
| `persistence.accessModes` | `[ReadWriteOnce]` | Single writer. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 100m / mem 256Mi` | |
| `resources.limits` | `cpu 2 / mem 2Gi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | Editor HTTP. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts).

## Architecture

A single-replica Deployment (Recreate strategy, RWO PVC) runs code-server, which
execs the image's bundled Node runtime directly against the compiled VS Code tree
and binds `0.0.0.0:8080`. `$HOME` (`/home/coder`) is a PersistentVolumeClaim
holding the user's workspace plus code-server state (settings, installed
extensions, `~/.local/share/code-server`); the OS temp dir is a separate emptyDir
so the root filesystem stays read-only. Login uses code-server's default
`--auth password`, with the password injected as the `PASSWORD` env from a
Secret via `secretKeyRef` (never in argv). Liveness and readiness both `httpGet
/healthz` (unauthenticated, 200 once the server is up). The container runs nonroot
on a read-only root filesystem with all capabilities dropped, and the image is
pinned by digest.

Because it holds a single RWO volume and one writer, code-server does not scale
horizontally — it stays at one replica. Front it with an Ingress (TLS) for real
use and keep the NetworkPolicy as the trust boundary.

## Uninstall

```bash
helm uninstall ide
```

The PVC is retained (delete it manually to discard the workspace).

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. code-server's built-in
`microsoft-authentication` and `npm-scripts` extensions are stripped from the
image (they drag a desktop GTK/webkit stack and a false-positive npm-CLI CVE
match, respectively); npm still runs from the integrated terminal.

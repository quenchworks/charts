# Quenchworks navidrome

Hardened [navidrome](https://www.navidrome.org/) music server and streamer
(Subsonic/OpenSubsonic API + web UI) on a minimal, nonroot, 0-CVE image pinned by
digest. Single node; persists its SQLite DB, scan cache and artwork to a PVC and
serves a music library mounted read-only.

## Install

```bash
helm install my-navidrome oci://ghcr.io/quenchworks/charts/navidrome
```

Then port-forward and open the web UI:

```bash
kubectl port-forward svc/my-navidrome-navidrome 4533:80
# http://127.0.0.1:4533  (first visit creates the admin account)
```

## Music library

The library is mounted read-only at `/music` (`ND_MUSICFOLDER`). A default install
uses an ephemeral empty dir so the server boots. For a real deployment, point at a
PVC holding your library:

```yaml
music:
  persistence:
    enabled: true
    existingClaim: my-music-pvc
```

Or mount a hostPath/NFS source via `extraVolumes` + `extraVolumeMounts`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/navidrome \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/navidrome \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/navidrome` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single node (SQLite); do not scale out. |
| `containerPort` | `4533` | Port navidrome binds (nonroot). Wired to `ND_PORT`. |
| `service.port` | `80` | Service port, forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC mounted at `/data` (SQLite DB + cache + artwork). |
| `persistence.size` | `1Gi` | |
| `persistence.existingClaim` | `""` | Bind an existing data PVC instead of provisioning one. |
| `music.persistence.enabled` | `false` | Off = ephemeral emptyDir library. Enable for a real PVC. |
| `music.persistence.existingClaim` | `""` | Bind an existing PVC holding your music library. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Pass extra navidrome config via `extraEnvVars` (any `ND_*` key), e.g.:

```yaml
extraEnvVars:
  - name: ND_SCANSCHEDULE
    value: "1h"
  - name: ND_LOGLEVEL
    value: info
```

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Writable paths are the `/data` PVC, the `/music` library mount (mounted
read-only), and an ephemeral `/tmp`. Navidrome serves `GET /ping` (returns HTTP
200), used for both liveness and readiness probes.

## Notes

Single node only: navidrome stores everything in a local SQLite database plus an
on-disk scan cache, so it cannot be horizontally scaled.

# Quenchworks FileBrowser Quantum

Hardened [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser), the maintained
successor to File Browser (whose upstream is archived): a self-hosted web file manager with
users, sharing, search and media previews. One Deployment serves the UI and API on port 8080.

The image is built from the upstream release tag with the web UI embedded in a single static
binary, runs as nonroot uid 1001, ships with 0 fixable CVEs, and is cosign-signed and pinned by
digest. It is built without MuPDF (AGPL; PDF previews only) and without the upstream analytics
reporter, so the pod makes no outbound calls of its own. Video previews use ffmpeg.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/filebrowser-quantum
kubectl port-forward svc/files-filebrowser-quantum 8080:8080
# http://127.0.0.1:8080, user `admin`; the password:
kubectl get secret files-filebrowser-quantum -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

The admin password applies when the database is first created. Change it in Settings after the
first login; later changes to `auth.adminPassword` do not touch an existing user.

To serve files that already exist, point `files.existingClaim` at their PersistentVolumeClaim.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/filebrowser-quantum \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/filebrowser-quantum@<digest> --owner quenchworks
```

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/filebrowser-quantum` | |
| `image.digest` | (CI-maintained) | Pinned image digest; never a tag. |
| `baseURL` | `/` | Serve the UI under a sub-path, e.g. `/files/`. |
| `sourceName` | `""` | Display name of the file source in the UI. |
| `auth.adminPassword` | `""` | Password of `admin` on first start. Empty: a random one is generated and kept across upgrades. |
| `auth.existingSecret` | `""` | Secret with keys `admin-password` and `jwt-secret`. |
| `auth.passwordMinLength` | `8` | Minimum password length. |
| `auth.signup` | `false` | Let visitors create accounts. |
| `extraConfig` | `{}` | Extra keys merged into `config.yaml`. |
| `persistence.enabled` | `true` | PVC for the SQLite database (users, shares, settings); off is an emptyDir. |
| `persistence.existingClaim` | `""` | Use an existing PVC for the database. |
| `persistence.size` | `1Gi` | |
| `files.enabled` | `true` | PVC for the served files, mounted at `/srv`; off is an emptyDir. |
| `files.existingClaim` | `""` | Serve an existing PVC. |
| `files.size` | `10Gi` | |
| `service.type` / `service.port` | `ClusterIP` / `8080` | |
| `ingress.enabled` | `false` | Optional Ingress for the UI. |
| `networkPolicy.enabled` / `networkPolicy.allowExternal` | `true` / `true` | Ingress to the UI port; set `allowExternal=false` to confine it to the namespace. |
| `resources` | 100m / 128Mi requests, 1 CPU / 1Gi limits | |

The common QuenchWorks knobs (`podLabels`, `nodeSelector`, `tolerations`, `extraEnvVars`,
`extraVolumes`, security-context overrides, probe overrides) work as in every QuenchWorks chart.

## Design

- **Single replica, Recreate.** Users, shares and settings live in one SQLite database owned by
  one pod; a second replica would split them. The old pod releases the volume before the new one
  starts.
- **Read-only root filesystem.** The config is a ConfigMap at `/etc/filebrowser`, the database is
  on `/home/filebrowser/data`, files on `/srv`, and the preview cache in an emptyDir at `/tmp`.
- **Secrets survive upgrades.** The generated admin password and JWT signing secret are read back
  from the existing Secret, so an upgrade does not sign every user out.
- **Probes** hit `/health`, which answers without authentication.

FileBrowser Quantum is Apache-2.0 licensed.

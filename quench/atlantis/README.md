# Quenchworks Atlantis

Hardened [Atlantis](https://github.com/runatlantis/atlantis) — Terraform/OpenTofu
pull-request automation — on a minimal, nonroot, 0-CVE image pinned by digest.
Built from source on Wolfi.

Atlantis listens for VCS webhooks, clones the PR branch, runs `plan`/`apply`, and
posts the output back as PR comments. The server (web UI + the `/events` webhook
endpoint + `/healthz`) listens on port **4141**.

## OpenTofu, not Terraform

This image **bundles [OpenTofu](https://github.com/opentofu/opentofu)** (MPL-2.0)
as the execution engine — **not Terraform** (which moved to the BUSL-1.1
source-available license). OpenTofu is a clean MIT/MPL-licensed drop-in. The chart
defaults `defaultTFDistribution: opentofu`, so Atlantis runs the bundled `tofu`
binary. You can verify it in the pod:

```bash
kubectl exec atlantis-atlantis-0 -- tofu version
```

## Install

```bash
helm install atlantis oci://ghcr.io/quenchworks/charts/atlantis \
  --set vcs.username=my-bot \
  --set vcs.githubToken=ghp_xxx \
  --set vcs.webhookSecret=$(openssl rand -hex 20) \
  --set repoAllowlist='github.com/myorg/*' \
  --set atlantisUrl=https://atlantis.example.com
```

## Wiring it up

1. **VCS credentials.** Set `vcs.username` + `vcs.githubToken` (a token for a bot
   account) and `vcs.webhookSecret`. These render into a managed Secret; or point
   `vcs.existingSecret` at your own Secret with keys `gh-token` /
   `gh-webhook-secret` (override via `vcs.secretKeys`). If `vcs.webhookSecret` is
   left empty a 32-char secret is generated once and preserved across upgrades.
2. **Repo allowlist.** Set `repoAllowlist` to the repos Atlantis may operate on
   (comma-separated, globs OK, e.g. `github.com/myorg/*`). **Required** — Atlantis
   refuses to start without it.
3. **Atlantis URL.** Set `atlantisUrl` to this server's externally reachable base
   URL.
4. **Webhook.** In your VCS, add a webhook pointing at `<atlantisUrl>/events` using
   the same webhook secret. Subscribe to pull-request + comment events.

Real `plan`/`apply` needs a **reachable VCS**: Atlantis clones the PR branch over
git (https or ssh — the image ships `git` + `openssh-client`) and posts results
back via the VCS API.

## Server-side repo config (optional)

Set `repoConfig` to an Atlantis server-side `repos.yaml`; it is rendered into a
ConfigMap, mounted at `/etc/atlantis/repos.yaml`, and passed via `--repo-config`.
The value is templated.

```yaml
repoConfig: |
  repos:
    - id: /.*/
      apply_requirements: [approved, mergeable]
      allowed_overrides: [workflow]
```

## Persistence

Atlantis keeps per-PR state on disk under `--data-dir` (`/atlantis-data`: cloned
repos + plan files), so the chart ships a **StatefulSet** with a persistent
volume. It also serialises plan/apply on disk and is not horizontally scalable —
keep `replicaCount: 1`.

| key | default | meaning |
|-----|---------|---------|
| `persistence.enabled` | `true` | provision a PVC for `/atlantis-data` |
| `persistence.size` | `8Gi` | PVC size |
| `persistence.existingClaim` | `""` | bind an existing PVC instead |

## Security

- Runs as nonroot **uid 1001**, `readOnlyRootFilesystem: true`, all capabilities
  dropped. Writable paths are the data PVC (`/atlantis-data`, also `$HOME`) and an
  emptyDir `/tmp`.
- A `NetworkPolicy` guards ingress on 4141. Because the VCS webhook source is
  typically **external**, `networkPolicy.allowExternal` defaults `true`; tighten it
  if your VCS reaches Atlantis from inside the cluster.
- The image is pinned by digest and signed (cosign keyless):

  ```bash
  cosign verify ghcr.io/quenchworks/images/atlantis \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

  Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
  with `gh attestation verify oci://ghcr.io/quenchworks/images/atlantis --owner quenchworks`.

## Key values

| key | default | meaning |
|-----|---------|---------|
| `vcs.provider` | `github` | VCS to integrate with |
| `vcs.username` | `""` | the bot user Atlantis acts as |
| `vcs.githubToken` | `""` | VCS API token (or use `vcs.existingSecret`) |
| `vcs.webhookSecret` | `""` | inbound webhook HMAC secret (auto-generated if empty) |
| `vcs.existingSecret` | `""` | bring your own credentials Secret |
| `repoAllowlist` | `""` | **required** — repos Atlantis may operate on |
| `atlantisUrl` | `""` | externally reachable base URL |
| `defaultTFDistribution` | `opentofu` | execution engine (`opentofu` / `terraform`) |
| `repoConfig` | `""` | optional server-side `repos.yaml` |
| `service.port` | `4141` | server + webhook + UI + `/healthz` |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
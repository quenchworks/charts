# Meilisearch (Quenchworks)

Quenchworks-hardened [Meilisearch](https://github.com/meilisearch/meilisearch) — a
fast, typo-tolerant full-text search engine. Runs from a minimal, nonroot, 0-CVE
image pinned by digest and cosign-signed. Single-node, with **mandatory** master-key
auth (`MEILI_ENV=production`) backed by a generated Secret.

- **App version:** 1.46.1 (MIT)
- **Image:** `ghcr.io/quenchworks/images/meilisearch` (multi-arch amd64+arm64, pinned by digest)
- **Topology:** StatefulSet, one replica (single node). The OSS engine has no built-in clustering.

## TL;DR

```sh
helm install my-meili oci://ghcr.io/quenchworks/charts/meilisearch
# fetch the generated master key:
kubectl get secret my-meili-meilisearch-masterkey -o jsonpath='{.data.master-key}' | base64 -d
```

## What it serves

| Port | Name   | Protocol | Purpose                |
|------|--------|----------|------------------------|
| 7700 | `http` | TCP      | REST search API        |

`GET /health` (on 7700) always returns `{"status":"available"}` and is
**unauthenticated** even with a master key set, so the liveness and readiness probes
keep working regardless of auth. The image **bundles the mini-dashboard** web UI;
Meilisearch serves it at `GET /` only in `MEILI_ENV=development` and **deliberately
hides it in production** (this chart runs production mode), where `GET /` returns the
JSON status `{"status":"Meilisearch is running"}`. See [Web dashboard](#web-dashboard-bundled-hermetically).

## Authentication

The chart runs Meilisearch with `MEILI_ENV=production`, which makes a **master key
mandatory**. Every API route except `GET /health` requires the header:

```
Authorization: Bearer <master-key>
```

The master key is resolved in this order:

1. **`auth.existingSecret`** — read the key from your own Secret (key `auth.existingSecretKey`, default `master-key`).
2. **`auth.masterKey`** — a literal value, stored in a chart-managed Secret.
3. **neither set (default)** — a strong 40-char key is **generated once** and
   **preserved across `helm upgrade`** via a `lookup` of the existing Secret.

Get the key from the chart-managed Secret:

```sh
kubectl get secret <release>-meilisearch-masterkey -o jsonpath='{.data.master-key}' | base64 -d
```

From the master key you can mint scoped API keys via `POST /keys` for least-privilege
clients (search-only keys, per-index keys, etc.) — see the Meilisearch security docs.

## Storage

Meilisearch keeps its index (LMDB) on local disk in `/meili_data/data.ms`, with dumps
and snapshots as sibling dirs under `/meili_data` (the DB path must be the LMDB dir
itself — Meilisearch's DB-version inference fails if that dir also holds sibling
dirs). The chart mounts a writable volume at `/meili_data` and runs on a read-only
root filesystem. `persistence.enabled=true` (default) provisions a PVC via a
`volumeClaimTemplate`; set `persistence.existingClaim` to reuse a PVC, or
`persistence.enabled=false` for an ephemeral `emptyDir` (testing only). `/tmp` is a
writable `emptyDir` scratch.

## Connecting

The REST API is exposed by a ClusterIP `Service`. From inside the cluster:

```
http://<release>-meilisearch.<namespace>.svc.cluster.local:7700
```

Port-forward to reach it from your workstation:

```sh
kubectl port-forward svc/<release>-meilisearch 7700:7700
KEY="$(kubectl get secret <release>-meilisearch-masterkey -o jsonpath='{.data.master-key}' | base64 -d)"
```

### Create an index, add documents, search

```sh
# 1) create an index keyed on "id"
curl -fsS -X POST http://127.0.0.1:7700/indexes \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"uid":"movies","primaryKey":"id"}'

# 2) add documents (async; Meilisearch indexes in the background)
curl -fsS -X POST http://127.0.0.1:7700/indexes/movies/documents \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '[{"id":1,"title":"Interstellar"},{"id":2,"title":"Inception"}]'

# 3) typo-tolerant search ("interstelar" still matches "Interstellar")
curl -fsS -X POST http://127.0.0.1:7700/indexes/movies/search \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"q":"interstelar"}'
```

A request without the key (or with a wrong key) is rejected with `401`/`403`.

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/meilisearch` | Image repo (pinned by `image.digest`). |
| `image.digest` | _CI-maintained_ | `sha256:...` digest; the contract with the image factory. |
| `replicaCount` | `1` | Single node; the OSS engine has no clustering. |
| `auth.masterKey` | `""` | Literal master key (else generated). |
| `auth.existingSecret` | `""` | Read the master key from this Secret instead. |
| `auth.existingSecretKey` | `master-key` | Key within `auth.existingSecret`. |
| `extraArgs` | `[]` | Extra flags appended to the `meilisearch` invocation. |
| `persistence.enabled` | `true` | Provision a PVC for `/meili_data`. |
| `persistence.size` | `8Gi` | PVC size. |
| `persistence.existingClaim` | `""` | Reuse an existing PVC. |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `7700` | REST API port. |
| `networkPolicy.enabled` | `true` | Restrict ingress to in-namespace pods. |
| `networkPolicy.allowExternal` | `false` | Allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | PDB with `minAvailable: 1`. |
| `resources` | requests 250m/256Mi, limits 1/1Gi | Container resources. |

Common production knobs (`nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `extraEnvVars`, `extraVolumes`, probe overrides, security
contexts, …) are wired through the shared `quench-common` library and merge over the
hardened defaults.

## Security posture

- Minimal Wolfi-based image, **built from source**, scanned **0-CVE** (Trivy, `--ignore-unfixed`).
- Runs as **nonroot** (uid 1001), **read-only root filesystem**, all Linux capabilities dropped.
- Image **pinned by digest** and **cosign keyless-signed**. Verify:

```sh
cosign verify ghcr.io/quenchworks/images/meilisearch \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/meilisearch --owner quenchworks`.

### Web dashboard (bundled, hermetically)

The image **bundles Meilisearch's `mini-dashboard` web UI**. Meilisearch serves it at
the root path `/` in `MEILI_ENV=development` and **intentionally disables it in
production** (this chart's mode) for security, where `GET /` returns the JSON status
instead. Upstream's `mini-dashboard` build step normally downloads a prebuilt asset bundle
from the network at compile time, which is incompatible with a hermetic from-source
build. Instead we vendor the EXACT pinned upstream `build.zip`
(`meilisearch/mini-dashboard` v0.4.1, sha256
`75f1f8b4fee7ff60179f519b853fa2f0cef347df95b24d9fc705e433797ac64d`), verify its
checksum, and feed it to the build offline via a tiny patch to `build.rs` — the
upstream sha1 integrity check is preserved, so the embedded assets are still verified
against the value pinned in Meilisearch's own `Cargo.toml`. Result: the dashboard is
compiled into the binary with **zero build-time network access**, reproducibly. Open
it over a port-forward at `http://127.0.0.1:7700/` and paste the master key.

Full multi-language, typo-tolerant tokenization (`all-tokenizations`) is also retained
(the complete upstream default feature set).

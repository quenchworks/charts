# Typesense (Quenchworks)

Quenchworks-hardened [Typesense](https://github.com/typesense/typesense) — a fast,
typo-tolerant search engine with an instant-search REST API and a **self-contained
embedded store** (no external database). Runs from a minimal, nonroot, 0-CVE image
pinned by digest and cosign-signed. Single-node, with **mandatory** API-key auth
backed by a generated Secret.

- **App version:** 30.2 (GPL-3.0)
- **Image:** `ghcr.io/quenchworks/images/typesense` (multi-arch amd64+arm64, pinned by digest)
- **Topology:** StatefulSet, one replica (single node).

## TL;DR

```sh
helm install my-ts oci://ghcr.io/quenchworks/charts/typesense
# fetch the generated API key:
kubectl get secret my-ts-typesense-apikey -o jsonpath='{.data.api-key}' | base64 -d
```

## What it serves

| Port | Name   | Protocol | Purpose         |
|------|--------|----------|-----------------|
| 8108 | `http` | TCP      | REST search API |

`GET /health` (on 8108) returns `{"ok":true}` and is **unauthenticated** even with an
API key set, so the liveness and readiness probes keep working regardless of auth.

## Authentication

Typesense **requires an API key** at startup and refuses to boot without one. Every
API route except `GET /health` requires the header:

```
X-TYPESENSE-API-KEY: <api-key>
```

The API key is resolved in this order:

1. **`auth.existingSecret`** — read the key from your own Secret (key `auth.existingSecretKey`, default `api-key`).
2. **`auth.apiKey`** — a literal value, stored in a chart-managed Secret.
3. **neither set (default)** — a strong 40-char key is **generated once** and
   **preserved across `helm upgrade`** via a `lookup` of the existing Secret.

Get the key from the chart-managed Secret:

```sh
kubectl get secret <release>-typesense-apikey -o jsonpath='{.data.api-key}' | base64 -d
```

The bootstrap key is the admin key; mint scoped, least-privilege keys via `POST /keys`
(search-only keys, per-collection keys, etc.) — see the Typesense API-keys docs.

## Storage

Typesense keeps its index and write-ahead log on local disk under its `--data-dir`
(the image defaults `TYPESENSE_DATA_DIR` to `/data`). The chart mounts a writable
volume at `/data` and runs on a read-only root filesystem. `persistence.enabled=true`
(default) provisions a PVC via a `volumeClaimTemplate`; set `persistence.existingClaim`
to reuse a PVC, or `persistence.enabled=false` for an ephemeral `emptyDir` (testing
only). `/tmp` is a writable `emptyDir` scratch.

## Connecting

The REST API is exposed by a ClusterIP `Service`. From inside the cluster:

```
http://<release>-typesense.<namespace>.svc.cluster.local:8108
```

Port-forward to reach it from your workstation:

```sh
kubectl port-forward svc/<release>-typesense 8108:8108
KEY="$(kubectl get secret <release>-typesense-apikey -o jsonpath='{.data.api-key}' | base64 -d)"
```

### Create a collection, index a document, search

```sh
# 1) create a collection
curl -fsS -X POST http://127.0.0.1:8108/collections \
  -H "X-TYPESENSE-API-KEY: $KEY" -H 'content-type: application/json' \
  -d '{"name":"books","fields":[{"name":"title","type":"string"}]}'

# 2) index a document
curl -fsS -X POST http://127.0.0.1:8108/collections/books/documents \
  -H "X-TYPESENSE-API-KEY: $KEY" -H 'content-type: application/json' \
  -d '{"id":"1","title":"The Hitchhiker Guide"}'

# 3) typo-tolerant search ("hitchiker" still matches "Hitchhiker")
curl -fsS "http://127.0.0.1:8108/collections/books/documents/search?q=hitchiker&query_by=title" \
  -H "X-TYPESENSE-API-KEY: $KEY"
```

A request without the key (or with a wrong key) is rejected with `401`.

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/typesense` | Image repo (pinned by `image.digest`). |
| `image.digest` | _CI-maintained_ | `sha256:...` digest; the contract with the image factory. |
| `replicaCount` | `1` | Single node. |
| `auth.apiKey` | `""` | Literal API key (else generated). |
| `auth.existingSecret` | `""` | Read the API key from this Secret instead. |
| `auth.existingSecretKey` | `api-key` | Key within `auth.existingSecret`. |
| `extraArgs` | `[]` | Extra flags appended to the `typesense-server` invocation. |
| `persistence.enabled` | `true` | Provision a PVC for `/data`. |
| `persistence.size` | `8Gi` | PVC size. |
| `persistence.existingClaim` | `""` | Reuse an existing PVC. |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `8108` | REST API port. |
| `networkPolicy.enabled` | `true` | Restrict ingress to in-namespace pods. |
| `networkPolicy.allowExternal` | `false` | Allow ingress from any source. |
| `podDisruptionBudget.enabled` | `true` | PDB with `minAvailable: 1`. |
| `resources` | requests 250m/256Mi, limits 1/1Gi | Container resources. |

Common production knobs (`nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `extraEnvVars`, `extraVolumes`, probe overrides, security
contexts, …) are wired through the shared `quench-common` library and merge over the
hardened defaults.

## Security posture

- Minimal Wolfi-based image (upstream's official per-arch binary), scanned **0-CVE** (Trivy, `--ignore-unfixed`).
- Runs as **nonroot** (uid 1001), **read-only root filesystem**, all Linux capabilities dropped.
- Image **pinned by digest** and **cosign keyless-signed**. Verify:

```sh
cosign verify ghcr.io/quenchworks/images/typesense \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/typesense --owner quenchworks`.

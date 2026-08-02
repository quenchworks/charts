# Quenchworks CockroachDB

> **LICENSE — NOT OPEN SOURCE.** CockroachDB is licensed under the **BSL-1.1
> (Business Source License 1.1)**, which is **NOT** an OSI-approved open-source
> license. Each released version automatically converts to Apache-2.0 three years
> after its release date. Do not represent CockroachDB as open source. SPDX:
> `BUSL-1.1`. This chart is **caution-tier**.
>
> **SECURITY — INSECURE BY DEFAULT.** This chart runs a **single-node, insecure**
> CockroachDB (no TLS, no auth). There are **no credentials**. The NetworkPolicy
> is the only access boundary. Secure mode (TLS/certs) and multi-node clustering
> are documented follow-ups.

Hardened [CockroachDB](https://github.com/cockroachdb/cockroach) — distributed SQL
speaking the PostgreSQL wire protocol — on a minimal, nonroot, 0-CVE image pinned by
digest. Ships CockroachDB's own official precompiled binary, hardened on Wolfi and
gated 0-CVE with Trivy. SQL (Postgres wire) is served on `26257` and the HTTP admin
UI / health endpoint on `8080`. Single node.

## Install

```bash
helm install crdb oci://ghcr.io/quenchworks/charts/cockroachdb
```

The node boots a single-node insecure cluster, relocating its store onto the
writable `/cockroach/cockroach-data` PVC (the rootfs is read-only).

## Connect

In insecure mode there is no password; the superuser is `root`.

```bash
# in-image SQL shell
kubectl exec -it crdb-cockroachdb-0 -- \
  cockroach sql --insecure --host=localhost:26257

# CREATE / INSERT / SELECT roundtrip
kubectl exec crdb-cockroachdb-0 -- \
  cockroach sql --insecure --host=localhost:26257 -e \
  "CREATE DATABASE demo; CREATE TABLE demo.t(id INT PRIMARY KEY, v STRING); INSERT INTO demo.t VALUES (1,'quench'); SELECT v FROM demo.t WHERE id=1;"

# any Postgres client (sslmode=disable, user root, no password)
psql "postgresql://root@crdb-cockroachdb:26257/defaultdb?sslmode=disable"
```

Health-check the readiness endpoint:

```bash
kubectl port-forward crdb-cockroachdb-0 8080:8080 &
curl -fsS "http://127.0.0.1:8080/health?ready=1"   # -> 200
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/cockroachdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/cockroachdb --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/cockroachdb` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node. |
| `persistence.enabled` | `true` | 8Gi PVC at `/cockroach/cockroach-data` (must allow exec). |
| `service.sqlPort` | `26257` | SQL / Postgres wire (client port). |
| `service.httpPort` | `8080` | HTTP admin UI / health (`/health?ready=1`). |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace — the boundary in insecure mode. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). Multi-node clustering is opt-in via `extraEnvVars`
(`COCKROACH_JOIN` plus a one-time `cockroach init`) and is a documented follow-up.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The store lives on the writable, exec-capable `/cockroach/cockroach-data`
PVC; `/tmp` is an emptyDir. Insecure mode has no TLS or auth, so keep CockroachDB
behind the NetworkPolicy for internal use only. Secure mode is a follow-up.

## Notes

Single node, insecure. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

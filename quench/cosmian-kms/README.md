# Quenchworks Cosmian KMS

> ### ⚠️ LICENCE — NOT OPEN SOURCE, AND CAPPED IN PRODUCTION
>
> Cosmian KMS is licensed under the **Business Source License 1.1**, which is **not**
> OSI-approved open source. Its Additional Use Grant permits production use only up to:
>
> > **2 vCPUs** on virtual machines, or **1 physical core** on bare metal — and **does not
> > include offering the Licensed Work to third parties.**
>
> This is **stricter than HashiCorp Vault's BUSL**, which restricts competing hosted
> offerings but allows unlimited *internal* production use. Scaling this past 2 vCPUs in
> production is a licence violation. The chart's default resource limit is set at 2 CPU to
> match the grant; raising it is your decision and your exposure.
>
> There is no open KMIP alternative to recommend instead: Vault's KMIP secrets engine is
> Enterprise-only, so [`quench/openbao`](../openbao) does not inherit it, and nothing else
> in this catalog speaks KMIP 2.1.

> ### Not FIPS 140-3
>
> Upstream describes itself as FIPS 140-3 compliant and builds in FIPS mode by default.
> That requires OpenSSL's FIPS provider, which Wolfi does not ship, so this image is built
> with the `non-fips` feature. **Do not inherit the FIPS claim** for this build.

KMIP 2.1 key management server on a minimal, nonroot, 0-CVE image built from source on
Wolfi, cosign-signed and pinned by digest.

## Install

```bash
helm install kms oci://ghcr.io/quenchworks/charts/cosmian-kms
```

SQLite on a PVC by default — no external database to provision.

## Storage

| `database.type` | Notes |
| --- | --- |
| `sqlite` (default) | A file on the PVC. **`replicaCount` is fixed at 1.** |
| `postgresql` | Supply `database.existingSecret` with a `url` key. |
| `mysql` | Same. |
| `redis-findex` | Same. |

**Why one replica with SQLite** — this is not a limitation to route around. The database is
a file on a `ReadWriteOnce` volume, so two replicas would be two *independent key stores*
behind one Service, handing out different keys depending on which pod answered. The schema
pins `replicaCount` to 1 for that reason. Moving to a shared backend lifts it — but note
that more replicas almost certainly exceeds the 2-vCPU licence grant.

With `persistence.enabled: false` the store is an `emptyDir` and **every key is lost when
the pod is replaced.** Fine for a smoke test, never for real use.

## TLS

Off by default, because in-cluster traffic is normally fronted by an Ingress or a mesh. But
everything this service returns is key material, so decide deliberately:

```yaml
tls:
  enabled: true
  existingSecret: kms-tls        # kubernetes.io/tls with tls.crt + tls.key
```

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Capped at 1 by the schema — see the storage note. |
| `server.port` | `9998` | Above 1024, so nonroot binds it with no capability. |
| `server.defaultUsername` | `admin` | Used when no auth method is configured. |
| `server.publicUrl` | `""` | Required for Google CSE / Microsoft DKE. |
| `database.type` | `sqlite` | `sqlite` \| `postgresql` \| `mysql` \| `redis-findex`. |
| `database.existingSecret` | `""` | Required for non-sqlite; holds the connection URL. |
| `persistence.enabled` | `true` | 8Gi PVC at `/var/lib/cosmian`. |
| `tls.enabled` | `false` | Terminate TLS in the server itself. |
| `extraConfig` | `{}` | Any other Cosmian env var, applied last so it wins. |
| `networkPolicy.allowExternal` | `false` | Closed by default — it is a KMS. |
| `ingress.enabled` | `false` | |

Plus the shared `quench-common` knobs: scheduling, probes, sidecars, init containers, extra
env/volumes, security contexts.

## Architecture notes

**The working directory matters.** The server creates its SQLite database *relative to its
CWD*, so the image sets `work-dir` to `/var/lib/cosmian` and the chart mounts the volume
there. If that path is not writable the process prints its entire configuration and then
**exits silently — no error line at all**, which is a genuinely hostile failure to debug.
Keep the mount and the work-dir in agreement.

**OpenSSL is Wolfi's, not vendored.** Upstream's `build.rs` downloads and compiles its own
OpenSSL 3.6.2; the recipe redirects it at Wolfi's current OpenSSL via `OPENSSL_DIR` and
fails the build if a vendored copy appears anyway. That is what keeps the image 0-CVE and
the SBOM honest. The running server reports its OpenSSL version on `/version`, so you can
check: it should say the Wolfi version and `non-FIPS`.

The `non-fips` build also means the **legacy provider is a real runtime dependency** — the
server loads it at startup and exits without it.

## Notes

KMIP 2.1 endpoint at `/kmip/2_1`; `/version` is the cheapest liveness signal. Cosmian's
`ckms` CLI and PKCS#11 provider are separate binaries and are not in this image. Depends on
the `quench-common` library chart from `oci://ghcr.io/quenchworks/charts/quench-common`.

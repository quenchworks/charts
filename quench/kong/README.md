# Quenchworks Kong Gateway

Kong Gateway OSS (Apache-2.0) on a minimal, nonroot, 0-CVE image built from source on
Wolfi, cosign-signed and pinned by digest. DB-less by default; Postgres-backed and
hybrid control-plane/data-plane topologies are both supported.

> **No Kong Manager GUI.** The image does not ship Kong's browser console. Its compiled
> assets are not in Kong's source tree and are not built from source upstream — Kong's own
> build downloads a prebuilt bundle from a Kong-hosted bucket, which cannot be honestly
> SBOM'd or built clean-room. Use the Admin API, [decK](https://github.com/Kong/deck), or
> a third-party OSS UI.
>
> **No ingress controller.** KIC is a separate image and is not part of this chart.

## Install

```bash
helm install kong oci://ghcr.io/quenchworks/charts/kong
```

DB-less out of the box: no database to provision, and every pod is independent.

## Topologies

### DB-less (default)

Configuration is a declarative document held in memory. No database, no migrations, no
shared state — so replicas scale freely and the HPA is genuinely safe.

The trade-off: **the Admin API is read-only.** You replace the whole config rather than
POSTing individual entities.

```yaml
database: "off"
declarativeConfig: |
  _format_version: "3.0"
  services:
    - name: example
      url: http://backend.default.svc.cluster.local:8080
      routes:
        - name: example-route
          paths: ["/api"]
```

### Database mode

```yaml
database: postgres
postgres:
  host: pg-rw.db.svc.cluster.local
  existingSecret: kong-pg-credentials
  ssl: true
  sslVerify: true
  luaSslTrustedCertificate: "system,/etc/kong/pg-ca/ca.crt"
migrations:
  enabled: true
```

Two things worth knowing:

- **`sslVerify` needs the CA in Kong's trust list.** `"system"` alone does not contain a
  private CA. Mount it with `extraVolumes` and list the path in
  `luaSslTrustedCertificate`. Project **only `ca.crt`** from a CA secret — a CNPG-style
  `-ca` secret also holds `ca.key`, the authority's private key, and mounting the whole
  secret hands Kong the ability to mint certificates for it.
- **Migrations run as Helm hooks**, never from the pod entrypoint: `bootstrap` on install,
  `migrations up` pre-upgrade, `migrations finish` post-upgrade. N replicas racing one
  schema is how a control plane corrupts itself.

### Hybrid: control plane + data plane

Two releases of this chart. The control plane owns the config and pushes it; data planes
proxy and hold it in memory.

```bash
# shared-mode mTLS: both sides present the SAME pair. Create it yourself --
# the chart will not mint a gateway trust anchor nobody audited.
kubectl create secret tls kong-cluster-cert --cert=tls.crt --key=tls.key

helm install kong-cp oci://ghcr.io/quenchworks/charts/kong \
  --set role=control_plane --set database=postgres \
  --set postgres.host=pg-rw --set postgres.existingSecret=kong-pg-credentials \
  --set migrations.enabled=true \
  --set cluster.enabled=true --set cluster.certSecret=kong-cluster-cert

helm install kong-dp oci://ghcr.io/quenchworks/charts/kong \
  --set role=data_plane \
  --set cluster.enabled=true --set cluster.certSecret=kong-cluster-cert \
  --set cluster.controlPlaneHost=kong-cp-cluster.kong.svc.cluster.local:8005 \
  --set cluster.telemetryHost=kong-cp-clustertelemetry.kong.svc.cluster.local:8006
```

What each role does:

| | proxy | Admin API | cluster ports |
| --- | --- | --- | --- |
| `traditional` (default) | yes | yes | – |
| `control_plane` | **off** | yes | listens 8005 / 8006 |
| `data_plane` | yes | **off** | connects to the CP |

Hybrid mode **refuses to render without `cluster.certSecret`**. That is deliberate:
without mTLS, any pod that can reach the cluster port could register as a data plane and
receive the entire configuration, credentials included.

## Ports

All above 1024, so the nonroot (uid 1001) container binds them with no capability. Same
numbers Kong documents.

| Port | Purpose |
| --- | --- |
| 8000 / 8443 | proxy (HTTP / HTTPS) |
| 8001 | Admin API — see the warning below |
| 8100 | `/status`, used by the probes |
| 8005 / 8006 | cluster config push / telemetry (hybrid only) |

## The Admin API is a control plane

It has **no authentication of its own**: anything that can reach it can create routes,
load plugins, and read every credential Kong holds. So this chart:

- keeps it **off the Service** unless you set `service.exposeAdmin=true`
- restricts it to the release namespace in the NetworkPolicy **even when
  `networkPolicy.allowExternal: true`** — that flag opens the proxy ports, never the
  Admin API

Widen it with `networkPolicy.extraFrom`, not by disabling the policy.

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `2` | Ignored when `autoscaling.enabled=true`. |
| `role` | `traditional` | `traditional` \| `control_plane` \| `data_plane`. |
| `database` | `"off"` | `"off"` (DB-less) or `postgres`. |
| `declarativeConfig` | empty-but-valid doc | DB-less only. An invalid or missing document makes Kong exit at startup. |
| `postgres.*` | – | host/port/db/user, `existingSecret`, `ssl`, `sslVerify`, `luaSslTrustedCertificate`. |
| `migrations.enabled` | `false` | Helm-hook Jobs: bootstrap / up / finish. |
| `cluster.*` | disabled | Ports, `mtls`, `certSecret`, DP endpoints, Service type + annotations. |
| `service.exposeAdmin` | `false` | Put the Admin API on the Service. Read the warning first. |
| `extraConfig` | `{}` | Any Kong setting as `KONG_<UPPER_SNAKE>`; applied last, so it wins. |
| `autoscaling.enabled` | `false` | Safe here — pods share no state in DB-less mode. |
| `networkPolicy.allowExternal` | `true` | Opens the proxy ports only. |
| `ingress.enabled` | `false` | Fronts the proxy port by default. |

Plus the shared `quench-common` knobs: scheduling, affinity, tolerations, probes,
sidecars, init containers, extra env/volumes, security contexts.

## Architecture notes

**`KONG_PREFIX` is `/kong_prefix`, not `/usr/local/kong`.** Kong regenerates its
`nginx.conf` and lmdb state in the prefix at every start, so it must be writable — but
`/usr/local/kong` also holds `include/`, the `.proto` files the opentelemetry and grpc
plugins load at runtime. Mounting a volume over `/usr/local/kong` **masks** them and Kong
dies with `module load error: opentelemetry/proto/...`. Keep the chart and image in
agreement on this.

Probes hit `/status` on the status port rather than the Admin API: it is the endpoint Kong
documents for health, it stays available in DB-less mode where the Admin API is read-only,
and it avoids exposing a control plane to the kubelet. `startupProbe` is generous because
Kong compiles every bundled plugin in `init_by_lua` before it listens.

## Notes

Built from source on Wolfi against Wolfi's **current** OpenSSL and PCRE, not Kong's pinned
OpenSSL 3.2.3 / PCRE 10.44 — both old enough to carry already-fixed CVEs. Kong's own 39
OpenResty patches are applied in full, including its six backported nginx CVE fixes.
Depends on the `quench-common` library chart from
`oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Caddy

Hardened [Caddy](https://github.com/caddyserver/caddy) web server with automatic
HTTPS on a minimal, nonroot, read-only-rootfs, 0-CVE image pinned by digest.
Built from source on Wolfi (no upstream distro binaries). Listens on `8080`
(http) and `8443` (https); the admin API is on `2019` (in-cluster only). Ports
are unprivileged because the container runs as nonroot uid 1001, which cannot
bind ports below 1024. Stateless: this chart runs a `Deployment` and scales
horizontally.

## Install

```bash
helm install web oci://ghcr.io/quenchworks/charts/caddy
```

Then reach it from inside the cluster:

```bash
kubectl run web-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://web-caddy:8080/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/caddy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/caddy --owner quenchworks`.

## Configuration

The chart serves a Caddyfile written to a ConfigMap and mounted read-only at
`/etc/caddy/Caddyfile` (the image entrypoint runs
`caddy run --config /etc/caddy/Caddyfile`). The default responds `200` on `/` over
the unprivileged HTTP port `8080` and enables the admin API on `2019`:

```caddyfile
{
	admin :2019
}
:8080 {
	respond "QuenchWorks Caddy OK" 200
}
```

Override `config.caddyfile` to serve your own site or a reverse proxy:

```yaml
config:
  caddyfile: |
    {
      admin :2019
    }
    :8080 {
      reverse_proxy upstream.svc.cluster.local:80
    }
```

Or point the chart at an externally-managed ConfigMap (its `Caddyfile` key is
mounted):

```yaml
config:
  existingConfigMap: my-caddyfile
```

### Automatic HTTPS

Caddy's automatic HTTPS issues and renews certificates on the `:8443` site when
the site address is a routable hostname. It needs the writable `/data` volume
(provided by this chart via an emptyDir) for certificate/state storage and
outbound reach to the ACME CA. Because `/data` is per-replica scratch, use a
shared storage module in the Caddyfile if you run multiple replicas behind one
hostname. For plain in-cluster HTTP, keep the default `:8080` site.

## Values

| Key                           | Default                            | Notes                                                                                     |
| ----------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/caddy` |                                                                                           |
| `image.digest`                | (CI-written)                       | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                | Stateless; scale freely (ignored when autoscaling is on).                                 |
| `config.caddyfile`            | `:8080 { respond ... 200 }`        | Inline Caddyfile mounted at `/etc/caddy/Caddyfile`.                                       |
| `config.existingConfigMap`    | `""`                               | Existing ConfigMap with a `Caddyfile` key; takes precedence over `config.caddyfile`.      |
| `service.port`                | `8080`                             | http (named `http`).                                                                      |
| `service.httpsPort`           | `8443`                             | https (named `https`).                                                                    |
| `service.adminPort`           | `2019`                             | admin API (named `admin`); in-cluster only.                                               |
| `autoscaling.enabled`         | `false`                            | Optional CPU HPA (`minReplicas`/`maxReplicas`).                                           |
| `networkPolicy.enabled`       | `true`                             | Ingress to 8080/8443 (admin always namespace-only).                                       |
| `networkPolicy.allowExternal` | `true`                             | A web server usually wants external ingress; set `false` to restrict to the namespace.    |
| `podDisruptionBudget.enabled` | `true`                             | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                            | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                               | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                               | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                             | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                               | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                               | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. Writable `emptyDir` volumes are
mounted at `/data` (certs/state, `$XDG_DATA_HOME`), `/config` (autosaved config,
`$XDG_CONFIG_HOME`) and `/tmp` — the only writable paths Caddy needs. Logs go to
stdout/stderr. The admin API on `2019` is never exposed outside the namespace.
The NetworkPolicy is the trust boundary.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks InfluxDB

Hardened [InfluxDB 2.x](https://www.influxdata.com/) on a minimal, nonroot, 0-CVE
image pinned by digest. The `influxd` server (and the `influx` CLI) is built from
source on Wolfi; the official prebuilt web UI bundle is embedded. The HTTP API and
the web UI are both served on port `8086`. Single node (InfluxDB 2.x OSS).

## Install

```bash
helm install tsdb oci://ghcr.io/quenchworks/charts/influxdb
```

On first boot the entrypoint runs `influx setup`, creating the admin user, org,
bucket, and an admin token. The password and token are stored in a Secret
(generated if you do not supply them).

## Connect

```bash
# admin token
kubectl get secret tsdb-influxdb -o jsonpath="{.data.admin-token}" | base64 -d
# admin password
kubectl get secret tsdb-influxdb -o jsonpath="{.data.admin-password}" | base64 -d
```

Write a point and query it back (token in `$TOKEN`):

```bash
HOST=http://tsdb-influxdb:8086
curl -fsS -XPOST "$HOST/api/v2/write?org=quench&bucket=default&precision=s" \
  -H "Authorization: Token $TOKEN" --data-binary 'cpu,host=a usage=0.64'
curl -fsS -XPOST "$HOST/api/v2/query?org=quench" \
  -H "Authorization: Token $TOKEN" -H 'Content-Type: application/vnd.flux' \
  --data-binary 'from(bucket:"default") |> range(start:-1h) |> filter(fn:(r) => r._measurement == "cpu")'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/influxdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/influxdb \
  --owner quenchworks
```

## Values

| Key                           | Default                               | Notes                                                                                     |
| ----------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/influxdb` |                                                                                           |
| `image.digest`                | (CI-written)                          | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                   | Single node (InfluxDB 2.x OSS).                                                           |
| `auth.setup`                  | `true`                                | Run `influx setup` on first boot.                                                         |
| `auth.username`               | `admin`                               | Admin user created by setup.                                                              |
| `auth.password`               | (generated)                           | 24-char random if empty; stored in the Secret.                                            |
| `auth.org`                    | `quench`                              | Initial organization.                                                                     |
| `auth.bucket`                 | `default`                             | Initial bucket.                                                                           |
| `auth.adminToken`             | (generated)                           | 48-char random if empty; stored in the Secret.                                            |
| `auth.retention`              | `""`                                  | Bucket retention (e.g. `30d`); empty means infinite.                                      |
| `auth.existingSecret`         | `""`                                  | Use an existing Secret for password + token.                                              |
| `persistence.enabled`         | `true`                                | 8Gi PVC at `/var/lib/influxdb2`.                                                          |
| `service.port`                | `8086`                                | HTTP API + web UI.                                                                        |
| `networkPolicy.enabled`       | `true`                                | Restricts HTTP ingress to the release namespace.                                          |
| `podDisruptionBudget.enabled` | `true`                                | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                               | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                  | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                  | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                                | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                  | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                  | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The engine/bolt/sqlite data lives on the writable `/var/lib/influxdb2`
volume; `/etc/influxdb2` (CLI configs) and `/tmp` are emptyDir. Credentials live in
a Kubernetes Secret. Keep InfluxDB behind the NetworkPolicy for internal use.

## Notes

Single node (InfluxDB 2.x OSS; clustering is an Enterprise feature). First-run
setup is idempotent: it runs only when the data dir is uninitialized, so restarts
and upgrades preserve the existing admin/org/bucket. Depends on the `quench-common`
library chart, pulled from `oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Grafana

Hardened [Grafana OSS](https://grafana.com/oss/grafana/) on a minimal, nonroot,
0-CVE image pinned by digest. Grafana is a single self-contained static Go binary;
the official OSS release artifact (AGPL-3.0) is hardened on Wolfi and gated 0-CVE.
The dashboard UI and HTTP API are both served on port `3000`. Single replica
(state in a local SQLite database on the PVC).

Pairs with the Quenchworks Prometheus and VictoriaMetrics charts as datasources.

## Install

```bash
helm install dash oci://ghcr.io/quenchworks/charts/grafana
```

The admin password is stored in a Secret (generated if you do not supply one).
There is no anonymous access by default.

## Connect

```bash
# admin password
kubectl get secret dash-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# reach the UI
kubectl port-forward svc/dash-grafana 3000:3000
# open http://127.0.0.1:3000  (user: admin)
```

Health check:

```bash
curl -fsS http://dash-grafana:3000/api/health
# -> {"database":"ok","version":"13.0.2"}
```

## Provision a datasource

Point Grafana at the Quenchworks Prometheus (or VictoriaMetrics) service. Set the
`datasources` value; it is rendered into a ConfigMap mounted into the provisioning
directory and wired on boot:

```yaml
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://victoriametrics:8428
```

## Configuration

Grafana ships `grafana.ini` read-only at `/etc/grafana/grafana.ini`. Override any
setting via `GF_<SECTION>_<KEY>` env using `config.extraIni`:

```yaml
config:
  extraIni:
    GF_SERVER_ROOT_URL: "https://grafana.example.com"
    GF_USERS_ALLOW_SIGN_UP: "false"
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/grafana \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/grafana \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/grafana` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single replica (SQLite state on the PVC). |
| `auth.adminUser` | `admin` | Admin user (`GF_SECURITY_ADMIN_USER`). |
| `auth.adminPassword` | (generated) | 24-char random if empty; stored in the Secret. |
| `auth.existingSecret` | `""` | Use an existing Secret for the admin user + password. |
| `config.extraIni` | `{}` | Map of `GF_<SECTION>_<KEY>` env overrides. |
| `datasources` | `[]` | Provisioned datasources (e.g. Prometheus/VictoriaMetrics). |
| `persistence.enabled` | `true` | 8Gi PVC at `/var/lib/grafana`. |
| `service.port` | `3000` | Dashboard UI + HTTP API. |
| `networkPolicy.enabled` | `true` | Ingress on port 3000. |
| `networkPolicy.allowExternal` | `true` | A dashboard UI is usually reached externally; set false to restrict to the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The SQLite database and plugins live on the writable `/var/lib/grafana`
volume; logs (`/var/log/grafana`), the provisioning tree
(`/etc/grafana/provisioning`), and `/tmp` are emptyDir. Admin credentials live in a
Kubernetes Secret, and there is no anonymous access by default.

## Notes

Single replica (Grafana OSS keeps state in a local SQLite database; HA needs an
external Postgres/MySQL backend, a tracked follow-up). Depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

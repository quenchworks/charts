# Quenchworks Harbor

Hardened [Harbor](https://goharbor.io/) — a cloud-native OCI registry with RBAC,
replication, vulnerability scanning and signing — as a **single umbrella chart** that
wires seven minimal, nonroot, 0-CVE component images (pinned by digest) over the
Quenchworks PostgreSQL and Valkey charts.

Every container runs as uid 1001 with a **read-only root filesystem** and **all
capabilities dropped**; each writable path is an `emptyDir` (or a PVC for registry
storage). There is no upstream "prepare" bootstrap container — this chart generates
every credential itself and persists it across upgrades.

## Components

| Component        | Role                                              | Optional |
|------------------|---------------------------------------------------|----------|
| core             | API, token service, `/v2` docker-protocol proxy   | no       |
| jobservice       | async jobs (GC, replication, scan, retention)     | no       |
| registry         | docker distribution (blob/manifest storage)       | no       |
| registryctl      | GC / quota controller (2nd container w/ registry) | no       |
| portal           | web UI (static SPA on nginx)                       | no       |
| proxy            | front-door nginx: `/` -> portal, API paths -> core | no       |
| trivy adapter    | vulnerability scanner (`trivy.enabled`)            | yes      |
| metrics exporter | Prometheus metrics (`metrics.enabled`)             | yes      |

Backing services: **PostgreSQL** (one database, `registry`; core auto-migrates the
schema on boot) and **Valkey** (six logical redis DBs multiplexed: core, registry,
jobservice, cache-layer, trivy-store, trivy-jobqueue). Both are bundled by default and
can be swapped for external instances.

> The Harbor CLI and content-trust/notary signing are **out of scope** for this chart.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL + Valkey with deterministic creds,
# fronted by a Traefik Ingress on host harbor.local
helm install reg oci://ghcr.io/quenchworks/charts/harbor \
  --set ingress.host=harbor.example.com --set externalURL=https://harbor.example.com
```

## Admin login

User `admin`. The password is generated once (and persisted across upgrades) unless
you pin it with `auth.adminPassword`.

```bash
kubectl get secret reg-harbor -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d ; echo
```

## docker login + push/pull

```bash
docker login harbor.example.com           # admin + the password above
docker tag alpine harbor.example.com/library/alpine
docker push harbor.example.com/library/alpine
docker pull harbor.example.com/library/alpine
```

The **token service** is the trust anchor: the chart generates an RSA keypair, gives
the private key to core (it signs registry-auth bearer tokens) and core validates them
at `/service/token`. This is separate from internal TLS (which is disabled for
in-cluster plaintext traffic). `externalURL` (or the ingress host) **must** match the
host you `docker login` to, or token-audience checks reject pulls/pushes.

## Front door

The whole app is reachable through **one** Service: the `proxy` (an nginx front door,
`proxy.enabled`, default true) routes `/` to the portal (UI) and `/api`, `/service`,
`/v2`, `/c`, `/chartrepo` to core. Its Service is named after the release (e.g.
`reg-harbor`) and maps port 80 -> proxy 8080. Port-forward THAT service to reach Harbor:

```bash
kubectl port-forward svc/reg-harbor 8080:80   # then open http://127.0.0.1:8080/
```

A **Traefik Ingress** (`ingress.enabled`, default true; `ingress.className: traefik`)
sits in front of the proxy Service. Set `ingress.host` and (if unset) `externalURL` is
derived from it; with no ingress, `externalURL` defaults to the in-cluster proxy Service
URL. When `proxy.enabled=false` the chart falls back to fronting core/portal directly
(set `ingress.enabled=false` and an explicit `externalURL`).

## Vulnerability scanning (Trivy)

```bash
helm upgrade reg oci://ghcr.io/quenchworks/charts/harbor --reuse-values --set trivy.enabled=true
```

Core registers the adapter as the default scanner (`WITH_TRIVY=true`); it downloads the
Trivy DB at runtime. Trigger scans from the UI or the scan API.

## Metrics

```bash
helm upgrade reg oci://ghcr.io/quenchworks/charts/harbor --reuse-values --set metrics.enabled=true
```

The exporter serves `:8001/metrics`; core/registry/jobservice expose their own metrics
ports too.

## External PostgreSQL / Valkey

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: pg.example.com
  user: harbor
  password: <pw>          # or set existingSecret
  database: registry      # must already exist; core migrates the schema
valkey:
  enabled: false
externalCache:
  host: redis.example.com
  password: <pw>
```

## Persistence

Registry storage is a PVC (`persistence.enabled`, default `50Gi`, path `/storage`).
The optional Trivy cache PVC is `trivy.persistence.enabled`. For ephemeral test
installs set `persistence.enabled=false` (emptyDir).

## Image verification

Images are pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/harbor-core \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

See [`values.yaml`](./values.yaml) and [`values.schema.json`](./values.schema.json).
Key knobs: `images.<component>.{repository,digest}`, `auth.adminPassword`,
`externalURL`, `ingress.*`, `postgresql.*`/`externalDatabase.*`,
`valkey.*`/`externalCache.*`, `persistence.*`, `trivy.*`, `metrics.*`,
`networkPolicy.*`, `podDisruptionBudget.*`.

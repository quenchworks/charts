# logging-stack

A hardened, **operator-free** Kubernetes logging bundle: Loki, Grafana and Vector
wired together into end-to-end log aggregation, with a ready-made logs dashboard
loaded out of the box. Vector tails every pod's logs on every node and ships them
to Loki; Grafana queries Loki through a pre-provisioned datasource.

It delivers the everyday value of a Loki/Promtail/Grafana ("LPG") stack — collect,
store and browse cluster logs — **without a logging operator and without CRDs**. Log
collection is a plain Vector DaemonSet with the built-in `kubernetes_logs` source
(cluster-wide, annotation-free), so there are no custom resources to install, no
admission webhooks, and no operator pod to keep healthy. Every component image is
QuenchWorks-hardened: built from source on Wolfi, nonroot, 0 fixable CVEs,
cosign-signed with an SBOM and SLSA provenance, and pinned by digest.

| Component | Role | Source |
|-----------|------|--------|
| **Loki** | log storage + LogQL query API (single-binary, filesystem) | `quench/loki` |
| **Grafana** | logs dashboard; Loki pre-wired as the default datasource | `quench/grafana` |
| **Vector** | per-node log shipper (tails pod logs → Loki) | templated inline |

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+ (OCI support)

## Usage

The chart is distributed as an OCI artifact:

```sh
oci://ghcr.io/quenchworks/charts/logging-stack
```

### Install

```sh
helm install logs oci://ghcr.io/quenchworks/charts/logging-stack
```

Open Grafana and read the generated admin password:

```sh
kubectl get secret logs-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo
kubectl port-forward svc/logs-grafana 3000:3000
# http://127.0.0.1:3000  (user: admin) — the "Loki" datasource is the default
```

The bundled dashboard appears under **Dashboards** immediately; logs start flowing
within ~30s of Vector starting. In **Explore**, query `{namespace="default"}`.

### Uninstall

```sh
helm uninstall logs
```

This removes everything the chart created. **No CRDs are installed, so there is
nothing to clean up afterwards.** The Loki and Grafana PersistentVolumeClaims are
retained by Helm convention; delete them by hand if you want the data gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=logs
```

### Upgrade

```sh
helm upgrade logs oci://ghcr.io/quenchworks/charts/logging-stack
```

There are no CRDs, so upgrades never require a separate CRD apply step. A major chart
version bump signals a breaking values change; check the release notes.

## How it's wired

The umbrella owns a thin glue layer; Loki and Grafana otherwise pass straight through
to their component charts.

- **Grafana datasource** — the umbrella renders a fixed-name ConfigMap
  (`logging-stack-datasources`) pointing at `http://<release>-loki:3100` with a fixed
  datasource uid `loki`, mounted into Grafana's provisioning directory via
  `grafana.extraVolumes`. `grafana.datasources` stays empty. **Fixed names ⇒ run one
  logging-stack per namespace.**
- **Dashboard** — the "Loki Kubernetes Logs" JSON ships in `dashboards/`, rendered into
  a ConfigMap and provisioned through a Grafana file provider (same mount mechanism as
  the datasource). No Grafana sidecar image required.
- **Vector → Loki** — Vector runs as a DaemonSet (one pod per node) templated **by this
  umbrella**, not the `quench/vector` component chart. It uses the built-in
  `kubernetes_logs` source to tail `/var/log/pods` on each node, enriches each event
  with pod metadata from the apiserver, and pushes to the `loki` sink at
  `http://<release>-loki:3100/loki/api/v1/push`. Logs are labelled `namespace`, `pod`,
  `container`, `node` and `stream`.
- **RBAC** — the umbrella creates a ServiceAccount + ClusterRole + binding for Vector
  granting read (`get`/`list`/`watch`) on `pods`, `namespaces` and `nodes` — what the
  `kubernetes_logs` source needs to enrich and discover logs cluster-wide.

### Why Vector is templated inline (not a dependency)

The `quench/vector` component chart is deployment-only and renders its `vectorConfig`
verbatim with `toYaml`, so it cannot run as a DaemonSet, cannot mount host log dirs,
and — critically — cannot template `{{ .Release.Name }}` into the Loki sink endpoint
(the config is data, not a template). A log shipper needs all three. So this umbrella
templates the Vector DaemonSet + its config ConfigMap + RBAC directly, exactly as the
`observability-stack` templates `node-exporter` inline. The Vector image is the same
hardened `ghcr.io/quenchworks/images/vector`, pinned by digest.

### Why no operator?

A logging operator's main jobs are CRD-driven pipeline config and lifecycle
management. This stack trades those for a single Vector config you edit directly and a
plain DaemonSet. You lose CRD-based config and gain a smaller, simpler, hardened
footprint with nothing cluster-scoped to upgrade.

## Dashboards

One curated dashboard ships in the chart and provisions automatically:

| Dashboard | Shows | Needs |
|-----------|-------|-------|
| Loki Kubernetes Logs | live log viewer filtered by namespace / container / stream + a match query | Loki + Vector |

Choose how many you want — all, some, or none:

```yaml
# All (default): nothing to set.

# Some: keep the ones you want, drop the rest.
dashboards:
  include:
    loki-kubernetes-logs: true

# None: Grafana installs with no bundled dashboards.
dashboards:
  enabled: false
```

To add your own, import JSON through the Grafana UI (persisted on the Grafana PVC),
or add files to `dashboards/` and re-release. The bundled dashboard is normalized to
bind its datasource to the provisioned `loki` uid.

## Ship your application's logs

There is nothing to annotate: Vector tails **every** pod's stdout/stderr on every
node and pushes it to Loki, so your app's logs appear in Grafana the moment the pod
runs. Query them in **Explore**:

```logql
{namespace="my-app", container="web"} |= "error"
```

To collect logs from a **file inside a container** (not stdout/stderr), or to parse /
transform events before they reach Loki, edit the Vector config. The inline config
lives in `templates/vector.yaml`; the supported component set (sources, transforms,
VRL, sinks) is documented in the `quench/vector` chart's `values.yaml`. Common
additions: a `file` source, a `remap` (VRL) transform, extra Loki labels.

## Loki storage

Loki runs in **single-binary** mode with **filesystem** storage (the `quench/loki`
chart default): one process runs every Loki target and keeps chunks/index/WAL on its
PVC. This is the recommended topology up to a few hundred GB/day of ingest. For more,
or for multi-tenant retention, move to scale-out Loki with an object store — a tracked
follow-up. Tune retention and limits through the `loki.lokiConfig` passthrough.

## Multiple releases

The fixed-name datasource and dashboard ConfigMaps mean **one logging-stack per
namespace**. Vector's log discovery is already cluster-wide, so a single release
collects logs from every namespace; install one stack and query any namespace in
Grafana.

## Configuration

See all options with:

```sh
helm show values oci://ghcr.io/quenchworks/charts/logging-stack
```

### Key values

| Value | Default | Notes |
|-------|---------|-------|
| `loki.enabled` / `grafana.enabled` / `vector.enabled` | `true` | per-component toggles |
| `loki.lokiConfig` | single-binary, filesystem, tsdb v13 | the full Loki config (templated) |
| `loki.persistence.size` | `16Gi` | Loki chunks/index PVC |
| `grafana.auth.adminPassword` | `""` | generated (24 chars) into the grafana Secret when empty |
| `dashboards.enabled` | `true` | provision the bundled dashboard (`false` = none) |
| `dashboards.include.<name>` | all `true` | per-dashboard toggle |
| `vector.enabled` | `true` | per-node log shipper (host DaemonSet) |
| `vector.digest` | (pinned) | Vector image digest |
| `vector.apiPort` | `8686` | Vector health/GraphQL API port (probes hit `/health`) |

`loki:` and `grafana:` values pass through to their component charts; see each
chart's `values.yaml` for the full surface.

## Security posture

- Operator-free: nothing cluster-scoped beyond the read-only RBAC Vector's log
  discovery needs (`pods`/`namespaces`/`nodes` get/list/watch).
- All images built from source on Wolfi, nonroot (uid 1001), 0 fixable CVEs.
- Images cosign-signed with SPDX SBOM + SLSA provenance, pinned by digest.
- Vector is the only host-touching piece: it mounts the node's `/var/log` and
  `/var/lib/docker/containers` **read-only**, runs nonroot with a read-only rootfs and
  all capabilities dropped, and is toggleable (`vector.enabled: false`).

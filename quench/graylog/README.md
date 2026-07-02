# Quenchworks Graylog

Hardened [Graylog](https://graylog.org/) — the log management / SIEM server — on a minimal,
nonroot, 0-CVE image pinned by digest and cosign-signed. Graylog runs as uid `1001` and
serves the web UI **and** REST API on port `9000`.

> **License notice — SSPL-1.0.** Graylog Server is licensed under the **Server Side Public
> License v1**, which is **source-available, NOT OSI-approved open source**. The Open Source
> Initiative has explicitly declined to approve the SSPL. Review the license (in particular
> its service/hosting conditions) before running Graylog in production or offering it as a
> service. This chart and the underlying image are Quenchworks-authored (clean-room); only
> the upstream Graylog artifact carries the SSPL terms.

Graylog is configured **entirely by environment variables** (each config key maps to a
`GRAYLOG_<KEY>` var) and needs **two backends**:

- **MongoDB** — configuration/metadata (users, streams, dashboards, inputs).
- **OpenSearch** (or Elasticsearch) — the indexed log message storage.

This chart bundles the Quenchworks **MongoDB** and **OpenSearch** charts by default and
provisions a small data PVC at `/var/lib/graylog` (rendered `server.conf`, node-id, message
journal). It can also point at external backends.

## Install

```bash
# self-contained: bundles in-cluster MongoDB + OpenSearch + a data PVC
helm install logs oci://ghcr.io/quenchworks/charts/graylog \
  --set graylog.externalUri="https://graylog.example.com/" \
  --set graylog.adminPassword="ChangeMeAdmin" \
  --set mongodb.auth.rootPassword="ChangeMeRoot"
```

- `graylog.externalUri` is **required** — the web UI's asset/API base and redirects derive
  from it. It must end with a trailing slash.
- `graylog.adminPassword` is **required** — you log into the web UI with
  `graylog.adminUsername` (default `admin`) and this password. The plaintext is never stored:
  the chart renders only its sha256 (`GRAYLOG_ROOT_PASSWORD_SHA2`) into a managed Secret.
- `graylog.passwordSecret` (`GRAYLOG_PASSWORD_SECRET`, >= 16 chars) encrypts stored
  credentials; left empty it is generated (random 96-char) and reused across upgrades.
- Set `mongodb.auth.rootPassword` for a deterministic install (otherwise it is generated and
  shared with Graylog's connection URI via `lookup`).

## Connect

```bash
kubectl port-forward svc/logs-graylog 9000:9000
# UI + API: http://localhost:9000/  (login: admin / your graylog.adminPassword)
```

## Backends

**MongoDB (config/metadata).** By default the bundled Quenchworks MongoDB subchart is
deployed; its primary Service is `<release>-mongodb` on port `27017`. Graylog connects as the
root user against the `admin` authSource, using database `graylog.mongodbDatabase`
(default `graylog`). The full `mongodb://` URI (with the resolved root password) is built into
this chart's managed Secret and injected as `GRAYLOG_MONGODB_URI`, so it never appears in the
pod's process arguments. To use an external MongoDB, set `mongodb.enabled=false` and provide
`externalMongodb.uri` (or `externalMongodb.existingSecret` carrying the URI key).

**OpenSearch (log storage).** By default the bundled Quenchworks OpenSearch subchart is
deployed; its Service is `<release>-opensearch` on port `9200`, with the security plugin
disabled for internal use, so Graylog reaches it over plain `http` with no auth
(`GRAYLOG_ELASTICSEARCH_HOSTS`). To use an external cluster, set `opensearch.enabled=false`
and provide `externalOpensearch.hosts` (comma-separated, credentials embedded in the URI if
required).

## Message inputs

Graylog inputs (GELF, Syslog, Beats, …) are created at runtime in the UI. To let their
traffic reach the pod, declare their ports under `service.inputs`; each entry is added to the
Service, the container ports and the NetworkPolicy ingress:

```yaml
service:
  inputs:
    - { name: gelf-tcp, port: 12201, protocol: TCP }
    - { name: syslog-udp, port: 1514, protocol: UDP }
```

## Security

The web UI + API are authenticated, but exposure is still scoped. By default
`networkPolicy.allowExternal` is `false`, restricting ingress to the release namespace. Front
Graylog with an ingress/TLS proxy and set `allowExternal=true` to expose it. The pod runs
nonroot (uid `1001`) with a read-only root filesystem; writes go only to the data PVC and a
`/tmp` emptyDir.

## Image provenance

The image is pinned by digest and cosign-signed (keyless / Sigstore):

```bash
cosign verify ghcr.io/quenchworks/images/graylog \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/graylog` | Image repo |
| `image.digest` | pinned `sha256:…` | Immutable image digest (CI-maintained) |
| `graylog.externalUri` | `http://localhost:9000/` | Public URI (**required**, trailing slash) |
| `graylog.adminPassword` | `""` | Admin password (**required**; only sha256 stored) |
| `graylog.passwordSecret` | `""` | Server secret (>= 16 chars; generated if empty) |
| `graylog.mongodbDatabase` | `graylog` | MongoDB database name |
| `graylog.serverJavaOpts` | `""` | Override JVM opts (image bakes `-Xmx1g`) |
| `replicaCount` | `1` | Graylog replicas (data PVC is ReadWriteOnce) |
| `service.port` | `9000` | Web UI + REST API port |
| `service.inputs` | `[]` | Extra message-input ports to expose |
| `persistence.size` | `8Gi` | Data PVC size (`/var/lib/graylog`) |
| `mongodb.enabled` | `true` | Deploy the bundled MongoDB backend |
| `opensearch.enabled` | `true` | Deploy the bundled OpenSearch backend |
| `networkPolicy.allowExternal` | `false` | Allow ingress from outside the namespace |

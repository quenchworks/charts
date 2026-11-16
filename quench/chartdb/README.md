# Quenchworks ChartDB

Hardened [ChartDB](https://github.com/chartdb/chartdb): a database diagram editor and visualizer. Import a schema with
one query (PostgreSQL, MySQL, SQL Server, SQLite, ClickHouse and more), edit ER diagrams, export DDL. Diagrams stay in
the browser. The image builds the app from source and serves it with nginx as uid 1001 on a read-only root
filesystem; it is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install erd oci://ghcr.io/quenchworks/charts/chartdb --set tls.enabled=true
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `hideCloud` | `true` | Hide the links to ChartDB's hosted cloud |
| `disableAnalytics` | `true` | Turn the app's analytics off |
| `ai.apiKey`, `ai.endpoint`, `ai.model` | `""` | Optional AI features; `/config.js` is public, so the key is too |
| `tls.enabled` | `false` | Native TLS on the same port (existingSecret, cert-manager or a Helm-generated CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/chartdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

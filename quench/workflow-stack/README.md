# Quenchworks workflow-stack

Durable workflow orchestration in one install: [Temporal](https://github.com/temporalio/temporal)
1.32.2 with PostgreSQL and the [Temporal UI](https://github.com/temporalio/ui-server) 2.58.1, on
QuenchWorks images (nonroot, CVE-gated at build, pinned by digest, cosign-signed). Temporal's
schema-setup Job creates both databases at install, a post-install Job registers the namespaces
you list, and the UI is wired to the frontend.

## Install

```bash
helm install workflows oci://ghcr.io/quenchworks/charts/workflow-stack -n temporal --create-namespace
```

Point workers at `workflow-temporal.temporal:7233`, namespace `default`.

## Values

| Key | Default | Notes |
|---|---|---|
| `temporal.*` | | passes to the [temporal chart](../temporal): `numHistoryShards` (fixed at first install), `postgresql.*`, `externalDatabase.*`, `tls.*` |
| `temporal-ui.enabled` | `true` | |
| `temporal-ui.*` | | passes to the [temporal-ui chart](../temporal-ui): `readOnly`, `ingress`, `tls` |
| `namespaces` | `[{name: default, retention: 72h}]` | registered once, after install |

## Notes

- One stack per namespace: the Temporal Service has the fixed name `workflow-temporal`
  (`temporal.fullnameOverride`), so the UI can be pointed at it from plain values.
- Namespaces are registered after the first install only. Add one later with the temporal CLI:
  `temporal operator namespace create --namespace <name> --address workflow-temporal:7233`.
- The temporal chart's NetworkPolicy admits clients from this namespace only. Run workers here,
  or set `temporal.networkPolicy.allowExternal=true`.
- `temporal.tls.enabled=true` turns on TLS at the frontend; then give the UI the CA with
  `temporal-ui.temporal.tls.caSecret` (the temporal chart's TLS Secret, key `ca.crt`).
- The UI has no login of its own. Use `temporal-ui.readOnly`, or put it behind an
  authenticating proxy.

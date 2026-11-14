# Quenchworks temporal-ui

The [Temporal UI](https://github.com/temporalio/ui-server) 2.58.1 on the QuenchWorks image (built
from source, no shell, nonroot, CVE-gated at build, pinned by digest, cosign-signed): workflows
and their event histories, schedules, namespaces and task queues of a Temporal cluster.

## Install

```bash
helm install temporal-ui oci://ghcr.io/quenchworks/charts/temporal-ui -n temporal \
  --set temporal.address=temporal-temporal:7233
```

`temporal.address` is the frontend gRPC address of the Temporal cluster (for the QuenchWorks
`temporal` chart installed as release `temporal`, the Service `temporal-temporal`, port 7233). The `workflow-stack` chart installs both and wires them.

## Values

| Key | Default | Notes |
|---|---|---|
| `temporal.address` | (required) | frontend gRPC, `host:port` |
| `temporal.tls.caSecret` | `""` | Secret with the CA of a TLS frontend (key `temporal.tls.caKey`); empty: plain gRPC |
| `defaultNamespace` | `default` | the namespace the UI opens on |
| `publicPath` | `""` | serve under a sub-path, e.g. `/temporal` |
| `readOnly` | `false` | hide start, signal, cancel, terminate, reset and batch actions |
| `tls.enabled` | `false` | HTTPS on the UI's own listener; self-signed unless `existingSecret` or `certManager` |
| `ingress.enabled` | `false` | |

## Notes

- The UI has no login of its own. Anyone who reaches it can act on workflows unless
  `readOnly` is set. Put it behind an authenticating proxy, or configure OIDC through the
  upstream `TEMPORAL_AUTH_*` variables in `extraEnvVars`.
- The NetworkPolicy of the `temporal` chart admits clients from its own namespace only. Install
  the UI in the same namespace, or set `networkPolicy.allowExternal=true` there.
- Version checks and the news feed are off: the pods call only the Temporal frontend.

# Quenchworks profiling-stack

Continuous profiling in one install: [Grafana Pyroscope](https://github.com/grafana/pyroscope)
stores CPU, memory, goroutine and lock profiles, and Grafana comes with the Pyroscope
datasource already provisioned, so flame graphs are one click away in Explore. It is the
"P" next to the logging, metrics and tracing stacks. No operator and no CRDs; both pods run
nonroot (uid 1001) on read-only root filesystems, and every image is 0-CVE, cosign-signed
and pinned by digest.

```
your app --(Pyroscope SDK push, or Grafana Alloy pyroscope.write)--> <release>-pyroscope:4040
Grafana --(Pyroscope datasource)--> Explore -> Pyroscope
```

## Install

```bash
helm install prof oci://ghcr.io/quenchworks/charts/profiling-stack
kubectl get secret prof-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/prof-grafana 3000:3000
```

Point your apps at `http://prof-pyroscope.<namespace>.svc:4040` (the SDK's server address,
or an Alloy `pyroscope.write` endpoint). Profiles show up in Grafana under Explore, with
Pyroscope selected as the default datasource.

## Values

| Key | Default | Notes |
|---|---|---|
| `pyroscope.enabled` | `true` | Any pyroscope chart value under `pyroscope.` passes through. |
| `pyroscope.persistence.size` | `8Gi` | Profile blocks and the metastore. |
| `grafana.enabled` | `true` | Any grafana chart value under `grafana.` passes through. |
| `grafana.auth.adminPassword` | generated | Kept in `<release>-grafana`. |
| `ingress.enabled` | `false` | Fronts Grafana unless `ingress.serviceName` says otherwise. |

The datasource ConfigMap has a fixed name, so run one profiling-stack per namespace. Keep
`grafana.datasources` empty; the stack provides the Pyroscope datasource itself.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/pyroscope \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

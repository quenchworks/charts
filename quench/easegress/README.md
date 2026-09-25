# Easegress

[Easegress](https://github.com/easegress-io/easegress) is a traffic orchestration
gateway written in Go: HTTPServer objects accept traffic (HTTP/1.1, HTTP/2, HTTP/3) and
route it to Pipelines, chains of filters such as Proxy, RateLimiter, Validator or
ResponseBuilder. Objects are stored in the embedded etcd. This chart runs one member on
the QuenchWorks easegress image as a StatefulSet with a PVC for that etcd. The image is
nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install gw oci://ghcr.io/quenchworks/charts/easegress \
  --set 'trafficPorts[0].name=http' --set 'trafficPorts[0].port=10080'
kubectl exec -i gw-easegress-0 -- egctl apply -f - <<'YAML'
name: demo-pipeline
kind: Pipeline
flow:
  - filter: proxy
filters:
  - name: proxy
    kind: Proxy
    pools:
      - servers:
          - url: http://my-backend.default.svc:8080
---
name: demo-server
kind: HTTPServer
port: 10080
rules:
  - paths:
      - pathPrefix: /
        backend: demo-pipeline
YAML
```

The admin API on 2381 has no authentication and full control of the gateway. Keep it
cluster-internal.

## Values

| Key | Default | Meaning |
|---|---|---|
| `initialObjects` | `[]` | objects created on startup if they do not exist yet; later edits do not change them, use `egctl apply` |
| `trafficPorts` | `[]` | container and Service ports for your HTTPServer objects (`name`, `port`) |
| `extraArgs` | `[]` | extra `easegress-server` flags |
| `persistence.enabled` | `true` | a PVC for `/data/easegress` (embedded etcd data and WAL) |
| `persistence.size` | `8Gi` | PVC size |
| `service.adminPort` | `2381` | admin API port on the ClusterIP Service |

The chart runs one member. Clustering several members through the embedded etcd is not
wired up; run more gateways as separate releases, or point members at a standalone etcd
with `extraArgs`. Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind with an HTTPServer and a Pipeline seeded from
`initialObjects`, checks the reported version against the chart's appVersion, sends a
request through the traffic port that the Pipeline proxies to the admin API, creates a
second object at runtime, deletes the pod, and requires that object back from etcd on the
PVC.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

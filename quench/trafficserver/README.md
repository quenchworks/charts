# Quenchworks Apache Traffic Server

Hardened [Apache Traffic Server](https://github.com/apache/trafficserver) (ATS), the caching
HTTP/1.1, HTTP/2 and TLS reverse proxy, built from source on a minimal, shell-free, nonroot,
CVE-gated image, cosign-signed and pinned by digest. It runs as a Deployment on a read-only
rootfs, listens on `8080` (and `8443` with TLS), and caches responses on disk.

## Install

```bash
helm install edge oci://ghcr.io/quenchworks/charts/trafficserver \
  --set 'remap[0]=map / http://my-app.default.svc.cluster.local:8080/'
```

ATS answers `404 Not Found on Accelerator` for any request that no remap rule maps, so a
release without `remap` proxies nothing. Each entry in `remap` is one line of
[remap.config](https://docs.trafficserver.apache.org/en/latest/admin-guide/files/remap.config.en.html),
in order:

```yaml
remap:
  - map http://www.example.com/ http://web.default.svc.cluster.local:8080/
  - map http://api.example.com/ http://api.default.svc.cluster.local:9000/
  - map / https://origin.internal/
```

## Tuning records.yaml

Any `proxy.config.*` record can be overridden from `records`. The chart passes each one as
ATS's `PROXY_CONFIG_*` environment variable, which takes precedence over `records.yaml`:

```yaml
records:
  proxy.config.http.cache.http: "0"            # proxy without caching
  proxy.config.diags.debug.enabled: "1"
  proxy.config.diags.debug.tags: "http"
```

`proxy.config.http.server_ports` is set by the chart (8080, plus the TLS port when
`tls.enabled`); set it in `records` only if you need different listeners.

## Cache

`cache.size` (default `256M`) is written to `storage.config`. The cache lives in an emptyDir,
so it starts cold on every pod. Set `cache.persistence.enabled=true` for a PVC that survives
restarts; with a ReadWriteOnce claim keep `replicaCount: 1`.

Hit and miss counters:

```bash
kubectl exec deploy/edge-trafficserver -- traffic_ctl metric match proxy.process.http.cache_
```

## TLS

`tls.enabled=true` adds a TLS listener on `service.tlsPort` (8443) using the chart's
certificate: a Helm-generated self-signed one by default, `tls.existingSecret`, or
cert-manager (`tls.certManager.enabled`). Plain HTTP on 8080 stays open for in-cluster
clients.

## Probes

The kubelet probes `/__hc`, answered by ATS's healthchecks plugin from a file before remap.
The probe does not depend on any remap rule or origin, and still proves `traffic_server` is
accepting and processing requests.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/trafficserver \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

# Quenchworks Varnish Cache

Hardened [Varnish Cache](https://github.com/varnish/varnish), the HTTP
reverse-proxy cache (web accelerator), on a minimal, nonroot, 0-CVE image,
cosign-signed and pinned by digest. Runs as a stateless Deployment, listens on
container port `8080`, and caches an origin's responses in memory.

## Install

```bash
# smoke install: no origin, Varnish answers everything itself
helm install cache oci://ghcr.io/quenchworks/charts/varnish

# useful install: cache an in-cluster origin
helm install cache oci://ghcr.io/quenchworks/charts/varnish \
  --set backend.host=my-app.default.svc.cluster.local \
  --set backend.port=8080
```

Point clients at the Service (port `80` by default) instead of the origin. Only
Varnish emits `X-Varnish`, so that header is how you confirm traffic is going
through the cache:

```bash
kubectl port-forward svc/cache-varnish 80:80
curl -i http://127.0.0.1:80/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/varnish \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/varnish --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/varnish` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Each replica has its own cache (ignored when autoscaling is on). |
| `backend.host` | `""` | Origin hostname. Empty = no backend; Varnish answers every request with a synthetic 200. |
| `backend.port` | `80` | Origin port. |
| `vcl.raw` | `""` | A COMPLETE VCL file, replacing the generated one. |
| `vcl.existingConfigMap` | `""` | ConfigMap with a `default.vcl` key; wins over `vcl.raw`. |
| `vcl.healthPath` | `/varnish-health` | Path the generated VCL answers from `vcl_synth`; both probes GET it. |
| `cacheSize` | `128m` | Passed as `-s malloc,<cacheSize>`. Keep it well under the memory limit. |
| `extraArgs` | `[]` | Extra `varnishd` flags, appended last (`-t`, `-p ...`). |
| `resources.requests` | `cpu 100m / mem 256Mi` | |
| `resources.limits` | `cpu 1 / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `80` | Maps to container port 8080. |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `autoscaling.minReplicas` | `1` | |
| `autoscaling.maxReplicas` | `5` | |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | |
| `serviceAccount.create` | `true` | Token automount is off. |
| `serviceAccount.name` | `""` | Use an existing ServiceAccount. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the `http` port. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`. |
| `ingress.hosts` | `[]` | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`. |
Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs `varnishd -F -f /etc/varnish/default.vcl -a
0.0.0.0:8080 -T 127.0.0.1:6082 -n /var/lib/varnish -s malloc,<cacheSize>` on
container port `8080`; the Service maps `service.port` onto it. The VCL is rendered
into a ConfigMap and mounted (via `subPath`) over `/etc/varnish/default.vcl`. Since
`varnishd` parses VCL only at startup, the pod template carries a `checksum/vcl`
annotation so editing the VCL rolls the Deployment.

Three consequences of how Varnish works, which the chart handles for you:

* **It compiles its VCL.** Varnish has no VCL interpreter — `varnishd` translates
  VCL to C, calls a compiler, and `dlopen()`s the result at every start and every
  `vcl.load`. The image therefore ships a toolchain, `/tmp` is a writable
  `emptyDir` for the compiler's scratch files, and the working directory must be
  writable **and** executable (`emptyDir` is; a `noexec` mount would stop Varnish
  from starting at all).
* **The working directory is not persistence.** `-n /var/lib/varnish` holds the
  shared-memory log, the CLI secret and the compiled VCL — an `emptyDir`, recreated
  per pod. The cache itself is `malloc` storage, so a restart or rollout starts
  cold and the first requests go to the origin.
* **Backend hostnames are resolved at VCL compile time.** Varnish pins the
  origin's IP when it compiles the VCL, not per request. So the origin Service must
  already exist when the pod starts (otherwise VCL compilation fails with "could
  not be resolved to an IP address" and the pod crash-loops until it does — restart
  backoff heals this on its own), and you should point `backend.host` at a normal
  **ClusterIP** Service, whose IP is stable. A headless Service resolves to pod IPs
  that move, and Varnish keeps the old one until the VCL is reloaded.
* **Health checks must not follow the origin.** Both probes `httpGet`
  `vcl.healthPath`, which the generated VCL answers from `vcl_synth`. That is a
  real HTTP round trip through `varnishd` (a `tcpSocket` probe would stay green
  even if the cache's child process had died) but it does not depend on the
  backend, so a sick origin does not restart the cache tier in front of it.

The admin CLI (`-T`) is bound to `127.0.0.1` deliberately — it can load VCL, ban
objects and change parameters. Reach it from inside the pod:

```bash
kubectl exec deploy/cache-varnish -- varnishadm -n /var/lib/varnish backend.list
kubectl exec deploy/cache-varnish -- varnishstat -1 -n /var/lib/varnish
kubectl exec deploy/cache-varnish -- varnishlog -n /var/lib/varnish
```

## Configuration examples

Cache an origin, keep objects for 5 minutes by default, and give Varnish more
threads:

```yaml
backend:
  host: web.default.svc.cluster.local
  port: 8080
cacheSize: 512m
extraArgs:
  - "-t"
  - "300"
  - "-p"
  - "thread_pool_max=2000"
resources:
  limits: { cpu: "2", memory: 1Gi }
```

Bring your own VCL. It must be complete, and it has to answer `vcl.healthPath`
itself or the probes will track the origin instead of Varnish:

```yaml
vcl:
  raw: |
    vcl 4.1;

    backend origin {
        .host = "web.default.svc.cluster.local";
        .port = "8080";
        .probe = {
            .url = "/healthz";
            .interval = 5s;
            .timeout = 2s;
            .window = 5;
            .threshold = 3;
        }
    }

    sub vcl_recv {
        if (req.url == "/varnish-health") { return (synth(200, "OK")); }
        # never cache the admin area
        if (req.url ~ "^/admin") { return (pass); }
        unset req.http.Cookie;
        set req.backend_hint = origin;
    }

    sub vcl_backend_response {
        set beresp.ttl = 10m;
        set beresp.grace = 1h;
    }

    sub vcl_synth {
        if (resp.status == 200) {
            set resp.body = "varnish OK";
            return (deliver);
        }
    }
```

## Uninstall

```bash
helm uninstall cache
```

Nothing persists — the cache is in memory and the chart creates no PVCs.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on
a read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. Varnish speaks plain HTTP only (no TLS terminator is built in) — put an
Ingress controller or another proxy in front of it for HTTPS, and keep the
NetworkPolicy as the trust boundary. `PURGE`/`BAN` requests are not enabled by
the generated VCL; add them with an ACL in your own VCL if you need cache
invalidation from the application.

# Quenchworks HAProxy

Hardened [HAProxy](https://github.com/haproxy/haproxy) high-performance TCP/HTTP load
balancer on a minimal, nonroot, read-only-rootfs, 0-CVE image pinned by digest. Built
from source on Wolfi (no upstream distro binaries) with OpenSSL, PCRE2 (+JIT), zlib,
and Lua. Frontends listen on unprivileged ports: `8080` (http), `8443` reserved for
TLS, `8404` (stats + health). Stateless: this chart runs a `Deployment`.

## Install

```bash
helm install lb oci://ghcr.io/quenchworks/charts/haproxy
```

Then reach it from inside the cluster:

```bash
# load-balanced traffic (the http_in frontend)
kubectl run lb-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://lb-haproxy:8080/

# stats + health
kubectl port-forward svc/lb-haproxy 8404:8404
curl http://127.0.0.1:8404/stats
curl http://127.0.0.1:8404/healthz
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/haproxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Configuration

The entire HAProxy config is driven by `config.haproxyConfig`, rendered verbatim into a
ConfigMap and mounted read-only at `/etc/haproxy/haproxy.cfg` (replacing the image's
sample). The default ships:

- a `global`/`defaults` pair tuned for a nonroot, read-only-rootfs runtime (no
  `user`/`group`/`chroot`/`daemon`; pidfile + admin socket under `/var/lib/haproxy`),
- a `stats` listener on `:8404` exposing `/stats` and a `/healthz` monitor-uri (what
  the liveness/readiness probes hit), and
- a sample http frontend on `:8080` -> `backend app`, which answers `200` itself until
  you point it at real servers.

Override `config.haproxyConfig` to run your own load-balancing topology:

```yaml
config:
  haproxyConfig: |
    global
        log stdout format raw local0
        maxconn 4096
        stats socket /var/lib/haproxy/admin.sock mode 660 level admin
    defaults
        log     global
        mode    http
        option  httplog
        timeout connect 5s
        timeout client  50s
        timeout server  50s
    frontend stats
        bind *:8404
        stats enable
        stats uri /stats
        monitor-uri /healthz
    frontend http_in
        bind *:8080
        default_backend app
    backend app
        server s1 10.0.0.1:80 check
        server s2 10.0.0.2:80 check
```

Keep the stats/health listener on `:8404` (or update `service.statsPort` and the
probes) and bind only **unprivileged** ports (>= 1024): the container runs as uid 1001
and cannot bind ports below 1024.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/quenchworks/images/haproxy` | Image repository. |
| `image.digest` | (CI-maintained) | Image digest; repinned automatically after each green image build. |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `replicaCount` | `1` | Number of HAProxy replicas. |
| `config.haproxyConfig` | (sample) | The full `haproxy.cfg`, rendered into a ConfigMap. |
| `resources` | `50m/32Mi` .. `500m/128Mi` | Container resource requests/limits. |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `8080` | Port for the http_in frontend (load-balanced traffic). |
| `service.statsPort` | `8404` | Port for the stats + health endpoint. |
| `serviceAccount.create` | `true` | Create a ServiceAccount (token automount disabled). |
| `rbac.create` | `false` | Create an (empty) Role + RoleBinding. |
| `networkPolicy.enabled` | `true` | Create a NetworkPolicy. |
| `networkPolicy.allowExternal` | `true` | Allow ingress from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | Create a PodDisruptionBudget. |
| `podDisruptionBudget.minAvailable` | `1` | Minimum available pods during disruption. |

Common production knobs (`podLabels`, `podAnnotations`, `nodeSelector`, `affinity`,
`tolerations`, `topologySpreadConstraints`, `extraEnvVars`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`, `podSecurityContext`,
`containerSecurityContext`, probe overrides, ...) are wired through `quench-common`.

## Security

- Runs as **nonroot** uid 1001 on a **read-only root filesystem** (writable `emptyDir`
  volumes at `/var/lib/haproxy` for the pidfile + admin socket and at `/tmp`).
- All Linux capabilities dropped; `runAsNonRoot` enforced via `quench-common`.
- Image is pinned by digest and signed with cosign (keyless / Sigstore).

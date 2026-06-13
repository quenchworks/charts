# Quenchworks Traefik

Hardened [Traefik](https://github.com/traefik/traefik) cloud-native edge router /
reverse proxy and Kubernetes ingress controller on a minimal, nonroot,
read-only-rootfs, 0-CVE image pinned by digest. Built on Wolfi. Deployed as a
cluster ingress controller that watches the Kubernetes API and routes traffic.

## Port mapping

The runtime image is nonroot (uid 1001), so the container cannot bind privileged
ports (<1024). Traefik listens on unprivileged container ports and the `Service`
maps the well-known ports onto them:

| entryPoint | container port | service port | purpose |
|-----------|----------------|--------------|---------|
| `web` | `8000` | `80` | plain HTTP |
| `websecure` | `8443` | `443` | HTTPS / TLS |
| `traefik` | `8080` | (in-cluster) | dashboard / api / `/ping` |

## Install

```bash
helm install edge oci://ghcr.io/quenchworks/charts/traefik
```

The `traefik.io` CRDs (the `IngressRoute` family) install automatically from the
chart's `crds/` directory (Helm 3 behaviour: installed on first install, never
upgraded or deleted by Helm).

## Reach the dashboard / api

The dashboard/api stay in-cluster by default. Port-forward the `traefik`
entryPoint:

```bash
kubectl port-forward deployment/edge-traefik 8080:8080
# dashboard: http://127.0.0.1:8080/dashboard/
# api:       http://127.0.0.1:8080/api/overview
# health:    http://127.0.0.1:8080/ping
```

`/ping` is always served (it backs the probes). The dashboard requires
`dashboard.enabled=true`; `dashboard.insecure=true` exposes the api with no auth on
the `traefik` entryPoint — convenient for port-forward, never expose it publicly.
Set `service.exposeDashboard=true` to publish the `traefik` port on the Service.

## Route traffic

Standard `Ingress` (the `kubernetesIngress` provider is on by default):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

Traefik `IngressRoute` (set `providers.kubernetesCRD=true`):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
spec:
  entryPoints: [web]
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      services:
        - name: my-app
          port: 80
```

## HTTPS / ACME

Set `acme.enabled=true` for a Let's Encrypt resolver named `le` (TLS challenge). A
writable `emptyDir` is mounted at the parent of `acme.storagePath` so `acme.json`
is writable under the read-only rootfs; mount a PVC there via
`extraVolumes`/`extraVolumeMounts` for durable certificates.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/traefik \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/traefik` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | |
| `ports.web` / `.websecure` / `.traefik` | `8000` / `8443` / `8080` | Unprivileged container ports; must stay >=1024. |
| `providers.kubernetesIngress` | `true` | Consume standard `Ingress` objects. |
| `providers.kubernetesCRD` | `false` | Consume the `traefik.io` `IngressRoute` family. |
| `ingressClass.create` | `true` | Create an `IngressClass` (controller `traefik.io/ingress-controller`). |
| `ingressClass.name` | `traefik` | Name Ingresses set as `ingressClassName`. |
| `ingressClass.isDefaultClass` | `false` | Make it the cluster default IngressClass. |
| `dashboard.enabled` | `true` | Serve the embedded dashboard at `/dashboard/`. |
| `dashboard.insecure` | `true` | `--api.insecure`; exposes api on the `traefik` entryPoint with no auth. |
| `acme.enabled` | `false` | Let's Encrypt resolver `le` (TLS challenge). |
| `acme.storagePath` | `/data/acme.json` | `acme.json` path; parent dir mounted writable. |
| `logLevel` | `INFO` | `DEBUG`/`INFO`/`WARN`/`ERROR`/`FATAL`/`PANIC`. |
| `extraArgs` | `[]` | Extra static-config CLI flags appended verbatim. |
| `service.type` | `ClusterIP` | |
| `service.port` / `.httpsPort` | `80` / `443` | Mapped to `web` / `websecure`. |
| `service.exposeDashboard` | `false` | Also publish the `traefik` port on the Service. |
| `rbac.create` | `true` | ClusterRole + ClusterRoleBinding for the providers. |
| `networkPolicy.enabled` | `true` | Ingress to web/websecure/traefik ports. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `crds.enabled` | `true` | CRDs ship in `crds/` and install via Helm 3. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## RBAC

An ingress controller is inherently cluster-scoped: the providers list/watch
`Ingresses`, `Services`, `Endpoints`/`EndpointSlices`, `Secrets`, and the
`traefik.io` CRDs cluster-wide. The chart creates a `ClusterRole` +
`ClusterRoleBinding` (and adds the CRD rules only when `providers.kubernetesCRD` is
on). The ServiceAccount token is mounted because Traefik must call the API server.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. Traefik writes nothing to the rootfs by
default; a writable `emptyDir` is mounted at `/tmp` (and at the ACME path when
enabled). Logs go to stdout/stderr.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The `traefik.io` CRDs are
vendored verbatim from the upstream v3.7 release (API definitions, not chart logic).

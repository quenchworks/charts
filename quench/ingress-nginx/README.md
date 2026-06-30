# Quenchworks ingress-nginx

Hardened [Ingress NGINX Controller](https://github.com/kubernetes/ingress-nginx)
on a minimal, nonroot, 0-CVE image, pinned by digest. The controller watches
`Ingress` resources of the `nginx` IngressClass and configures NGINX to
load-balance and route HTTP/HTTPS traffic to backend Services, with a validating
admission webhook that rejects malformed Ingress objects before they are
persisted.

## Install

```sh
helm install ingress-nginx oci://ghcr.io/quenchworks/charts/ingress-nginx \
  -n ingress-nginx --create-namespace
```

## Architecture

A single controller Deployment runs `/usr/bin/nginx-ingress-controller` (plus
NGINX in-process). Alongside it the chart ships the IngressClass, the controller
ConfigMap, cluster + namespaced RBAC, and the admission webhook.

| Resource | Role |
|----------|------|
| `<release>-controller` Deployment | watches Ingresses, renders nginx.conf, serves data-plane `:80`/`:443`, healthz/metrics `:10254`, admission webhook `:8443` |
| `<release>-controller` Service | data-plane entrypoint (LoadBalancer by default) |
| `<release>-controller` ConfigMap | global NGINX config the controller watches |
| IngressClass `nginx` | controller `k8s.io/ingress-nginx` |
| ClusterRole/Binding + Role/Binding | cluster-wide read of the Ingress inputs + namespaced leader-election Lease and ConfigMap |
| `<release>-controller-admission` (Service + ValidatingWebhookConfiguration + Secret) | validates `Ingress` objects |

### Admission webhook certificate

The webhook needs a serving cert the apiserver trusts. This chart **generates a
self-signed CA + serving cert with Helm** (Sprig `genSignedCert`) into the Secret
`<release>-controller-admission`, mounts it into the controller, and bakes the
matching `caBundle` straight into the `ValidatingWebhookConfiguration`. So **no
cert-manager, no extra Jobs, and no second image** are required. The cert is
re-used across upgrades via a `lookup` of the existing Secret, and is only minted
on a fresh install.

### Hardening

The controller runs nonroot (uid 1001), with a read-only root filesystem, seccomp
`RuntimeDefault`, and **all** Linux capabilities dropped except `NET_BIND_SERVICE`
(it legitimately binds `:80`/`:443` directly). Because the image is minimal and
shell-free, an init container seeds an `emptyDir` with the image's `/etc/nginx`
tree (lua scripts, modules, modsecurity rules, templates) using the image's own
LuaJIT, so the controller can rewrite `nginx.conf` / `lua/cfg.json` at runtime
while the real root filesystem stays read-only. Writable `emptyDir`s are mounted
at `/tmp`, `/etc/nginx`, `/etc/ingress-controller` and `/var/log/nginx`.

## Smoke test

```sh
kubectl create deploy echo --image=hashicorp/http-echo:1.0.0 -- -text=hello -listen=:8080
kubectl expose deploy echo --port=80 --target-port=8080

kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: echo }
spec:
  ingressClassName: nginx
  rules:
    - host: echo.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: { service: { name: echo, port: { number: 80 } } }
EOF

# Through the controller Service address (or a NodePort / port-forward):
curl -H 'Host: echo.local' http://<controller-address>/   # -> hello
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/ingress-nginx` | controller image |
| `image.digest` | (CI-maintained) | signed multi-arch index; never a tag |
| `ingressClass.name` | `nginx` | the IngressClass this controller serves |
| `ingressClass.isDefaultClass` | `false` | make it the cluster default IngressClass |
| `ingressClass.controllerValue` | `k8s.io/ingress-nginx` | controller identity |
| `controller.replicaCount` | `1` | |
| `controller.service.type` | `LoadBalancer` | use `NodePort` on kind/bare-metal |
| `controller.service.nodePorts.http` | `""` | NodePort for HTTP when `type: NodePort` |
| `controller.admissionWebhooks.enabled` | `true` | the validating webhook for Ingress objects |
| `controller.admissionWebhooks.failurePolicy` | `Fail` | `Ignore` to fail-open |
| `controller.watchNamespace` | `""` (all) | restrict to a single namespace |
| `rbac.create` | `true` | required: cluster-wide read of Ingress inputs |
| `serviceAccount.create` | `true` | |

The image is pinned by digest and cosign-signed; verify with the command in the
post-install notes.

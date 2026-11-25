# Quenchworks HAProxy Kubernetes Ingress

Hardened [HAProxy Kubernetes Ingress Controller](https://github.com/haproxytech/kubernetes-ingress): serves Ingress
resources through HAProxy, with rate limiting, IP allow and deny lists, ACLs, redirects and TLS as annotations. The
image is the controller, gopherd and upstream's secret-blocking HAProxy wrapper built from source on QuenchWorks'
HAProxy 3.4; it runs as uid 1001 on a read-only rootfs, CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install haproxy oci://ghcr.io/quenchworks/charts/haproxy-kubernetes-ingress
```

Then route an Ingress with `spec.ingressClassName: haproxy`. An init container installs or updates the controller's
CRDs from the image on every rollout.

## Attack protection, per Ingress

```yaml
metadata:
  annotations:
    haproxy.org/deny-list: "203.0.113.0/24, 198.51.100.7"
    haproxy.org/rate-limit-requests: "100"
    haproxy.org/rate-limit-period: "10s"
```

The same keys without the prefix in `config` apply to every Ingress.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `ingressClass.name` | `haproxy` | The IngressClass this controller serves |
| `ingressClass.default` | `false` | Also serve Ingresses with no class |
| `config` | `{}` | Global annotations, as the controller's ConfigMap |
| `extraArgs` | `[]` | More controller flags |
| `service.type` | `LoadBalancer` | Public entry point (HTTP 80, HTTPS 443) |
| `resources.limits.memory` | `512Mi` | gopherd gives HAProxy two thirds of it, the controller one third |

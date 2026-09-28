# Quenchworks Homepage

Hardened [Homepage](https://github.com/gethomepage/homepage), a services and
bookmarks dashboard with live widgets for hundreds of self-hosted apps, built
from source, 0-CVE, cosign-signed and pinned by digest.

## Install

```bash
helm install homepage oci://ghcr.io/quenchworks/charts/homepage \
  --set 'allowedHosts[0]=home.example.com' \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=home.example.com'
```

## Allowed hosts

Homepage refuses any request whose Host header it does not know, with 400,
to block DNS rebinding. `localhost:3000` is always allowed, which is what
`kubectl port-forward` sends and what the chart's probes send. Every other
name users reach it by, such as the Ingress host, goes in `allowedHosts`. `"*"`
turns the check off.

## Configure the dashboard

Each key under `config` is one of Homepage's config files, written as YAML:

```yaml
config:
  services:
    - Media:
        - Jellyfin:
            href: https://jellyfin.example.com
            icon: jellyfin.png
  bookmarks:
    - Developer:
        - GitHub:
            - href: https://github.com
```

`helm upgrade` rolls the pod with the new files. A file you leave out is
created from Homepage's defaults on first start.

## Discover services from Kubernetes

Set `config.kubernetes.mode: cluster` and `rbac.create: true`. Homepage then
lists Ingresses, HTTPRoutes and Traefik IngressRoutes annotated with
`gethomepage.dev/enabled: "true"`, and the resource widgets read metrics. The
ClusterRole is read-only.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/homepage \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `allowedHosts` | `[]` | Extra Host headers Homepage answers |
| `config.settings` / `services` / `bookmarks` / `widgets` | see values | Config files |
| `config.kubernetes` | `mode: disabled` | `cluster` enables Kubernetes discovery |
| `config.docker` | `{}` | Docker integrations |
| `config.customCss` / `customJs` | `""` | custom.css and custom.js |
| `rbac.create` | `false` | Read-only ClusterRole for Kubernetes discovery |
| `ingress.enabled` | `false` | Ingress; add its host to `allowedHosts` |
| `service.port` | `3000` | Service port |

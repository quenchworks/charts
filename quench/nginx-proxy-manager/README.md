# Quenchworks Nginx Proxy Manager

Hardened [Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager), the
web UI that manages nginx proxy hosts, redirections, 404 hosts, TCP/UDP streams, access lists
and Let's Encrypt certificates, on a minimal, nonroot, CVE-gated image, cosign-signed and pinned
by digest. The image builds nginx from source (with the stream module), the backend with pinned
production dependencies, and the UI from source. It runs as uid 1001 on a read-only rootfs.

## Install

```bash
helm install npm oci://ghcr.io/quenchworks/charts/nginx-proxy-manager \
  --set admin.email=you@example.com --set service.type=LoadBalancer
```

The proxy Service publishes HTTP on 80 and HTTPS on 443. For Let's Encrypt certificates
(HTTP-01), port 80 of that Service must be reachable from the internet for every domain you
request a certificate for.

## Log in

The admin UI has its own ClusterIP Service, `<release>-nginx-proxy-manager-admin`, port 81:

```bash
kubectl port-forward svc/npm-nginx-proxy-manager-admin 8181:81
kubectl get secret npm-nginx-proxy-manager-admin -o jsonpath='{.data.password}' | base64 -d
# open http://127.0.0.1:8181 and log in as admin.email
```

The first admin account is created once, on the first start, from `admin.email` and a password
generated into `<release>-nginx-proxy-manager-admin` (kept on uninstall). Set `admin.password`
or `admin.existingSecret` (key `password`) to choose it. Change both in the UI afterwards.

`service.exposeAdmin=true` also publishes the admin port on the proxy Service. A tidier way to
reach the UI from outside is a proxy host in NPM itself that forwards to `127.0.0.1:8181`,
behind an access list.

## Admin TLS

`tls.enabled=true` serves the admin UI over HTTPS with the chart certificate: a Helm-generated
self-signed one by default, `tls.existingSecret`, or cert-manager (`tls.certManager.enabled`).
The sites NPM proxies get their certificates from NPM itself.

## Streams

NPM streams forward raw TCP or UDP. Each stream's incoming port must also be listed here so the
pod and the Service open it. The pod runs nonroot, so incoming ports must be 1024 or higher; the
Service can still publish a low port:

```yaml
streamPorts:
  - { name: ssh, port: 2222 }
  - { name: dns, port: 5353, protocol: UDP, servicePort: 53 }
```

## Differences from the upstream image

- Ports inside the pod are 8080 (HTTP), 8443 (HTTPS) and 8181 (admin), not 80, 443 and 81.
  The Service maps them back, so clients see the usual ports.
- Certificates use Let's Encrypt HTTP-01 or custom certificates. Upstream installs certbot DNS
  plugins with pip when a DNS challenge is first used; this image has no pip, so DNS challenges
  are not available.
- One replica. The SQLite database (or the `DB_MYSQL_*` / `DB_POSTGRES_*` settings in
  `extraEnvVars`) and the generated nginx config live on the `/data` volume; certbot's state is
  on a second volume at `/etc/letsencrypt`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nginx-proxy-manager \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

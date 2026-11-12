# Quenchworks Zoraxy

Hardened [Zoraxy](https://github.com/tobychui/zoraxy), the general-purpose reverse proxy with
a web UI: virtual hosts, ACME certificates, stream proxy, access rules and an uptime monitor.
The image is built from source with the web UI embedded, runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest. Zoraxy is AGPL-3.0.

Upstream's image also bundles ZeroTier, which is not open source at the version it ships; this
image leaves it out, so the ZeroTier page in the panel reports it as unavailable.

## Install

```bash
helm install zoraxy oci://ghcr.io/quenchworks/charts/zoraxy
kubectl port-forward svc/zoraxy 8000:8000
```

Open http://127.0.0.1:8000 and create the admin account straight away: on an empty install the
first visitor becomes the admin. Keep the admin port off the internet; only the proxy port needs
to be exposed (a LoadBalancer Service or an Ingress pointing at it).

## Ports

| Port | What |
|---|---|
| 8000 (`adminPort`) | Admin panel, plain HTTP |
| 8443 (`proxyPort`) | Proxy listener, TLS with the certificates managed in the panel (ACME or uploaded) |
| `extraPorts` | Listeners you add in the panel, such as stream proxy ports or an HTTP port for redirects |

The image runs as uid 1001, so listeners use ports above 1024; map 80/443 at the Service or
load balancer.

## Data

Config, the database, certificates and logs live in `/opt/zoraxy/data`, on a PVC
(`persistence.size`, default 1Gi). One replica only: the data is one volume.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/zoraxy \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

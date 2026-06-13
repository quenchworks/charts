# Quenchworks nginx

Hardened [nginx](https://nginx.org) web server / reverse proxy on a minimal,
nonroot, read-only-rootfs, 0-CVE image pinned by digest. Built from source on Wolfi
(no upstream distro binaries). Listens on `8080` (http); `8443` is reserved for TLS.
Stateless: this chart runs a `Deployment` and scales horizontally.

## Install

```bash
helm install web oci://ghcr.io/quenchworks/charts/nginx
```

Then reach it from inside the cluster:

```bash
kubectl run web-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://web-nginx:8080/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/nginx \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Custom configuration

The image ships a working default page on `8080` with `/stub_status` enabled, so no
config is required. The main `nginx.conf` includes `/etc/nginx/conf.d/*.conf`.

- Inline a server block — written to a ConfigMap and mounted at
  `/etc/nginx/conf.d/default-quench.conf`:

  ```yaml
  config:
    serverBlock: |
      server {
        listen 8080;
        location / { return 200 "hello from quench\n"; }
        location /stub_status { stub_status; }
      }
  ```

- Or mount an externally-managed ConfigMap of `*.conf` drop-ins:

  ```yaml
  config:
    extraConfigMap: my-nginx-confd
  ```

- Serve site content by mounting it at the doc root `/usr/share/nginx/html` via
  `extraVolumes` / `extraVolumeMounts`.

`/etc/nginx` is read-only in the image; to replace `nginx.conf` wholesale, mount
over it with `extraVolumeMounts`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/nginx` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless; scale freely (ignored when autoscaling is on). |
| `config.serverBlock` | `""` | Inline server block(s); mounted into `conf.d`. Empty -> built-in page. |
| `config.extraConfigMap` | `""` | Existing ConfigMap of `*.conf` drop-ins; takes precedence over `serverBlock`. |
| `service.port` | `8080` | http (named `http`). |
| `autoscaling.enabled` | `false` | Optional CPU HPA (`minReplicas`/`maxReplicas`). |
| `networkPolicy.enabled` | `true` | Ingress to port 8080. |
| `networkPolicy.allowExternal` | `true` | A web server usually wants external ingress; set `false` to restrict to the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. A writable `emptyDir` is mounted at
`/tmp` for nginx's pid and temp paths (the only writable dir the default config
needs). Logs go to stdout/stderr. The NetworkPolicy is the trust boundary.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. TLS on 8443 is left to the
operator (mount certs and add a server block); no TLS server is configured by
default.

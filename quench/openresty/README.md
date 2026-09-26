# Quenchworks OpenResty

[OpenResty](https://openresty.org) is nginx with LuaJIT and the lua-nginx-module set,
for scriptable proxies, API gateways and web apps. This chart runs it on the
QuenchWorks openresty image:
- built from source on Wolfi, linked against the system OpenSSL, PCRE2 and zlib
- shell-free and nonroot (uid 1001), with a read-only root filesystem
- 0 fixable CVEs, cosign-signed and pinned by digest

## Install

```sh
helm install gw oci://ghcr.io/quenchworks/charts/openresty
kubectl port-forward svc/gw-openresty 8080:8080
curl http://127.0.0.1:8080/
```

Out of the box the image serves its default page and `/stub_status` on 8080.

## Configuration

Server blocks go in `/etc/nginx/conf.d`, which the image's `nginx.conf` includes
inside `http {}`. Lua directives work there directly:

```yaml
config:
  serverBlock: |
    server {
        listen 8080;
        location / {
            content_by_lua_block { ngx.say("hello from ", jit.version) }
        }
    }
```

`config.serverBlock` is written to a ConfigMap and mounted as
`/etc/nginx/conf.d/default-quench.conf`. `config.extraConfigMap` mounts an existing
ConfigMap of `*.conf` files instead. Either one replaces the default server, so keep
a `listen 8080` server that answers `/` for the probes, or set `customLivenessProbe`
and `customReadinessProbe`.

`lua_ssl_trusted_certificate` is set to the system CA bundle, so cosockets
(`resty.http` and friends) can verify TLS upstreams.

## Values

| Key | Default | Meaning |
|---|---|---|
| `config.serverBlock` | `""` | inline server block(s), replaces the default server |
| `config.extraConfigMap` | `""` | existing ConfigMap mounted at `/etc/nginx/conf.d`; wins over `serverBlock` |
| `replicaCount` | `1` | stateless, scale freely |
| `autoscaling.enabled` | `false` | HPA on CPU |
| `service.port` | `8080` | HTTP port |
| `networkPolicy.allowExternal` | `true` | a proxy is meant to be reached |

## Limits of this image

- **No perl tools.** `resty`, `opm` and `restydoc` are perl scripts and are removed.
  Add Lua libraries by mounting them and setting `lua_package_path` in a conf.d
  drop-in; drop-ins are included at `http` level.
- **Leaner module set** than the official image: no GeoIP, XSLT, image filter or mail
  modules. HTTP/2 is included. The stream module is compiled in, but conf.d sits
  inside `http {}`, so a `stream {}` block needs your own `nginx.conf` mounted over
  `/usr/local/openresty/nginx/conf/nginx.conf`.

## Release gate

On kind, the gate installs the chart with an inline server block that runs Lua. It
requires LuaJIT to answer, `resty.sha256` to hash correctly through the linked
libcrypto, and `/stub_status` to report.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Quenchworks RSS-Bridge

Hardened [RSS-Bridge](https://github.com/RSS-Bridge/rss-bridge): Atom, JSON, HTML and other feeds for sites that have
none, with 400+ bridges. The image runs php-fpm behind QuenchWorks' nginx (only index.php executes) as uid 1001 on a
read-only root filesystem; it is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install feeds oci://ghcr.io/quenchworks/charts/rss-bridge --set 'enabledBridges={GithubIssueBridge,YoutubeBridge}'
kubectl get secret feeds-rss-bridge -o jsonpath='{.data.password}' | base64 -d   # basic auth, user admin
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `enabledBridges` | `["*"]` | The bridges served; list only what you need on a shared instance |
| `auth.enabled`, `auth.username` | `true`, `admin` | HTTP basic auth on every request |
| `auth.password`, `auth.existingSecret` | generated | The password, or a Secret with key `password` |
| `settings` | `{}` | More `RSSBRIDGE_<section>_<key>` settings, e.g. `RSSBRIDGE_cache_timeout` |
| `cache.sizeLimit` | `1Gi` | The per-pod file cache (emptyDir) |
| `tls.enabled` | `false` | Native TLS on the same port (existingSecret, cert-manager or a Helm-generated CA) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/rss-bridge \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

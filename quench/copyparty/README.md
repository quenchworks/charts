# Quenchworks copyparty

Hardened [copyparty](https://github.com/9001/copyparty): a portable file server with resumable uploads,
deduplication, WebDAV, media indexing, a markdown editor, accounts and per-volume permissions. The image
installs the release sdist into a venv on Wolfi Python with jinja2 from Wolfi; it runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install files oci://ghcr.io/quenchworks/charts/copyparty
kubectl get secret files-copyparty -o jsonpath='{.data.password}' | base64 -d   # log in as admin
```

copyparty serves plain HTTP here: put TLS on an ingress or gateway in front of the Service.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The account the chart creates |
| `admin.password`, `admin.existingSecret` | generated | Its password, or a Secret with key `password` |
| `volumes` | `[{url: /, path: /srv, access: "A,admin"}]` | Shares: URL, path under `/srv`, copyparty permission groups joined by `:` (`r`, `w`, `m`, `d`, `g`, `a`, `A`; a group with no names is everyone) |
| `extraArgs` | `[]` | More copyparty arguments, e.g. `-e2dsa` to index every file |
| `persistence.size` | `5Gi` | The files and copyparty's state (`/srv/.copyparty`, hidden) |

A public read-only share next to the private one:

```yaml
volumes:
  - { url: /, path: /srv/private, access: "A,admin" }
  - { url: /pub, path: /srv/pub, access: "r:A,admin" }
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/copyparty \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

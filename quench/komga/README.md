# Quenchworks Komga

Hardened [Komga](https://github.com/gotson/komga): a media server for comics, manga, BDs and ebooks (CBZ, CBR, PDF,
EPUB) with a web reader, OPDS, Kobo and KOReader sync, libraries, collections and read lists. The image is the
official release jar on Wolfi openjdk-21-jre with its vulnerable libraries swapped to fixed releases; it runs as uid
1001 on a read-only root filesystem and is CVE-gated at build, cosign-signed and pinned by digest. Three
spring-webmvc/webflux 6.2 advisories with no open-source 6.2 fix are not reachable in Komga and carry a VEX.

The chart claims the server with the first account after install, so it never waits unclaimed.

## Install

```bash
helm install komga oci://ghcr.io/quenchworks/charts/komga --set admin.email=you@example.com \
  --set media.existingClaim=my-comics --set tls.enabled=true
kubectl get secret komga -o jsonpath='{.data.admin-password}' | base64 -d
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.email`, `admin.password` | `admin@example.com`, generated | The first account, claimed by a post-install Job |
| `media.existingClaim` or `media.hostPath` | `""` | Your comics and books, mounted read-only at `media.mountPath` (`/media`) |
| `persistence.size` | `5Gi` | Databases, search index and thumbnails (`/var/lib/komga`) |
| `tls.enabled` | `false` | Native HTTPS on the same port (existingSecret, cert-manager or a Helm-generated CA) |
| `settings` | `{}` | Komga and Spring settings as environment variables, e.g. `SERVER_SERVLET_CONTEXT_PATH` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/komga \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

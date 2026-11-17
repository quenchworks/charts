# Quenchworks Calibre-Web

Hardened [Calibre-Web](https://github.com/janeczku/calibre-web): browse, read and download an ebook library kept
in a Calibre database, with users, shelves and an OPDS feed. The image runs the app from source in a Python venv
over Wolfi's native packages, as uid 1001 on a read-only root filesystem; it is CVE-gated at build, cosign-signed
and pinned by digest.

Upstream creates `admin` / `admin123` on the first start. This chart's init container sets the admin password from
a generated Secret before every start.

## Install

```bash
helm install books oci://ghcr.io/quenchworks/charts/calibre-web \
  --set library.existingClaim=my-calibre-library \
  --set ingress.enabled=true --set 'ingress.hosts[0].host=books.example.com' \
  --set 'ingress.tls[0].hosts[0]=books.example.com' --set 'ingress.tls[0].secretName=books-tls'
kubectl get secret books-calibre-web -o jsonpath='{.data.password}' | base64 -d   # sign in as admin
```

On first sign-in, set the library location to `/books`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `auth.username`, `auth.password` | `admin`, generated | The account the init container sets before every start |
| `auth.existingSecret` | `""` | A Secret with key `password` instead |
| `persistence.size` | `1Gi` | `/config`: settings, users and logs |
| `library.existingClaim` | `""` | A claim holding your Calibre library, mounted at `/books` |
| `library.size` | `20Gi` | The chart's own library volume when no claim is given |
| `ingress.*` | off | Calibre-Web has no TLS listener here: terminate TLS at the Ingress |

A password changed in the UI is reset on the next start: change `auth.password` instead. Ebook conversion
(Calibre's `ebook-convert`) is not in the image.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/calibre-web \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

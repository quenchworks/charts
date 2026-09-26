# Quenchworks Label Studio

[Label Studio](https://labelstud.io/), the open-source data labeling tool for text,
images, audio, video and time series, on a nonroot, 0-CVE image pinned by digest and
cosign-signed. It runs as uid `1001` on a read-only root filesystem and serves the UI
and REST API on port `8080`.

The chart bundles the Quenchworks PostgreSQL chart by default. It can also use an
external PostgreSQL, or SQLite on the data volume with both turned off.

## Install

```bash
helm install ls oci://ghcr.io/quenchworks/charts/label-studio \
  --set admin.username=you@example.com
```

The admin account is created, or its password reset, on every start. With
`admin.password` empty, a password is generated into the release Secret and kept
across upgrades:

```bash
kubectl get secret ls-label-studio -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/ls-label-studio 8080:8080   # then open http://localhost:8080/
```

## Values

| Key | Default | Notes |
|---|---|---|
| `admin.username` | `admin@example.com` | Admin email, created on start |
| `admin.password` | `""` | Generated when empty |
| `disableSignup` | `true` | Sign-up only through an invite link |
| `host` | `""` | Public URL; sets `LABEL_STUDIO_HOST` and `CSRF_TRUSTED_ORIGINS` |
| `persistence.size` | `10Gi` | Data volume: uploads, exports, SQLite, `SECRET_KEY` |
| `postgresql.enabled` | `true` | Bundled PostgreSQL |
| `externalDatabase.enabled` | `false` | Use `externalDatabase.*` instead |
| `networkPolicy.allowExternal` | `false` | Ingress only from the release namespace |
| `ingress.enabled` | `false` | Set `host` with it |

Cloud storage (S3, GCS, Azure) credentials go in `extraEnvVars` or
`extraEnvVarsSecret`.

## Notes

- One pod: the data volume is ReadWriteOnce and holds the generated Django
  `SECRET_KEY`. Losing it logs every user out.
- The image leaves out `opencv-python-headless`, whose wheel bundles OpenSSL 1.1.1w.
  Only the SDK's brush-to-COCO export needs it, so that export is unavailable.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/label-studio \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

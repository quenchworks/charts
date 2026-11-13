# Quenchworks changedetection.io

Hardened [changedetection.io](https://github.com/dgtlmoon/changedetection.io): watch web pages
for changes and get notified, CVE-gated, cosign-signed and pinned by digest. The image is the
app in a Python 3.13 virtualenv on a nonroot Wolfi base. It fetches with plain HTTP requests: the
Playwright browser fetcher and the OpenCV visual-diff extras are not bundled.

## Install

```bash
helm install cd oci://ghcr.io/quenchworks/charts/changedetection --set tls.enabled=true
kubectl port-forward svc/cd-changedetection 5000
```

Open `https://localhost:5000` and set a password (Settings > General) before exposing the
Service: until then anyone who reaches it can read and change every watch.

## Storage

`/datastore` holds the watches, settings and every snapshot on a PersistentVolumeClaim. One
replica with `Recreate`.

## API

The REST API key is generated on first start and kept in `/datastore/changedetection.json`
(Settings > API in the UI). `NOTES.txt` prints the command that reads it.

## Settings

`settings` sets environment variables, for example:

```yaml
settings:
  BASE_URL: https://changes.example.com
  HIDE_REFERER: "true"
```

changedetection.io refuses to fetch private and reserved addresses (an SSRF guard). To watch
services inside the cluster, set `settings.ALLOW_IANA_RESTRICTED_ADDRESSES: "true"`, knowing that
anyone who can add a watch can then make the pod fetch internal URLs.

## TLS

`tls.enabled` makes changedetection.io serve HTTPS itself on 5000. The certificate comes from
`tls.existingSecret`, then cert-manager (`tls.certManager`), else a Helm-generated CA.

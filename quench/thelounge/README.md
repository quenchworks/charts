# Quenchworks The Lounge

Hardened [The Lounge](https://github.com/thelounge/thelounge), a self-hosted web IRC client that stays
connected for you: always-on networks, history, push notifications and file uploads. The image installs
The Lounge from npm on Wolfi Node 24 with its pinned dependencies lifted to fixed versions; it runs as
uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install lounge oci://ghcr.io/quenchworks/charts/thelounge
kubectl get secret lounge-thelounge -o jsonpath='{.data.password}' | base64 -d   # user admin
kubectl port-forward svc/lounge-thelounge 9000:9000
```

With the [Ergo chart](https://quench-works.com) in the same namespace, point new connections at it:

```bash
helm install lounge oci://ghcr.io/quenchworks/charts/thelounge \
  --set defaults.host=irc-ergo --set defaults.port=6667 --set defaults.tls=false --set lockNetwork=true
```

The chart passes config.js entries as `-c key=value` flags, so the config.js on the volume keeps
upstream's defaults and everything the chart sets is visible in the pod spec.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `admin.username` | `admin` | The account the chart creates and keeps in step with the Secret |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `public` | `false` | No accounts: anyone can connect, nothing is kept |
| `reverseProxy` | `false` | Trust `X-Forwarded-For` from an ingress |
| `fileUpload` | `false` | Uploads and shareable links |
| `defaults.host`, `defaults.port`, `defaults.tls` | `irc.libera.chat`, `6697`, `true` | The network a new connection starts from |
| `lockNetwork` | `false` | Users can only connect to the default network |
| `settings` | `{}` | More config.js entries, e.g. `maxHistory: 5000` |
| `tls.enabled` | `false` | HTTPS on 9000 (existing Secret, cert-manager or a Helm-made CA) |

Message history is kept as text logs on the volume (the image has no SQLite module).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/thelounge \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

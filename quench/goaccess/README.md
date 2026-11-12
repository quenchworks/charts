# Quenchworks GoAccess

Hardened [GoAccess](https://goaccess.io), a real-time web log analyzer. It follows an access
log (nginx, Apache, Caddy, CloudFront, ELB, W3C and more), keeps the statistics in memory and
pushes them to a live HTML dashboard over WebSocket: visitors, requests, status codes, referrers,
browsers and operating systems. The image is built from source in C, runs as uid 1001 and is
CVE-gated at build, cosign-signed and pinned by digest; the report is served by our caddy image
in the same pod.

## Install

GoAccess reads the log from a PersistentVolumeClaim your web server or log shipper writes to:

```bash
helm install stats oci://ghcr.io/quenchworks/charts/goaccess \
  --set logs.existingClaim=nginx-logs --set logs.file=access.log --set logs.format=COMBINED
kubectl port-forward svc/stats-goaccess 8080 7890
```

Open `http://localhost:8080`; the page connects back to port 7890 for live updates.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `logs.existingClaim` | required | PVC with the access log (mounted read-only at `/logs`) |
| `logs.file`, `logs.format` | `access.log`, `COMBINED` | The file inside it and its format |
| `wsUrl` | `""` | WebSocket URL browsers use (`wss://host:7890` behind TLS) |
| `service.port`, `service.wsPort` | `8080`, `7890` | Report and WebSocket |
| `extraArgs` | `[]` | More flags (`--ignore-crawlers`, `--exclude-ip`) |

A ReadWriteOnce claim needs GoAccess on the same node as the writer; use ReadWriteMany storage
or schedule them together.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/goaccess \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

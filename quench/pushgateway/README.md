# Quenchworks Pushgateway

Hardened [Prometheus Pushgateway](https://github.com/prometheus/pushgateway): short-lived batch
and cron jobs push their metrics to it, and Prometheus scrapes them from there. The image is
built from source, runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by
digest.

## Install

```bash
helm install pgw oci://ghcr.io/quenchworks/charts/pushgateway
echo "backup_last_success $(date +%s)" | curl --data-binary @- http://pgw-pushgateway:9091/metrics/job/backup
```

Scrape it with `honor_labels: true` so the pushed `job` and `instance` labels survive.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `persistence.enabled` | `true` | Keep pushed metrics across restarts in a 1Gi PVC (`--persistence.file`) |
| `persistence.interval` | `5m` | How often the file is written |
| `adminApi` | `false` | Enable `/api/v1/admin/wipe` |
| `tls.enabled` | `false` | TLS on 9091 (existing Secret, cert-manager, or self-signed) |
| `extraArgs` | `[]` | More `pushgateway` flags |

Run one replica: each Pushgateway holds its own set of pushed groups. The Deployment uses the
Recreate strategy so the volume is never mounted twice.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pushgateway \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

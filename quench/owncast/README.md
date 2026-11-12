# Quenchworks Owncast

Hardened [Owncast](https://github.com/owncast/owncast), self-hosted live video streaming and
chat, CVE-gated, cosign-signed and pinned by digest. The image is built from source with Wolfi
ffmpeg for transcoding, on a nonroot base.

## Install

```bash
helm install owncast oci://ghcr.io/quenchworks/charts/owncast
kubectl port-forward svc/owncast 8080
```

Open `http://localhost:8080/admin` as `admin` with the generated password:

```bash
kubectl get secret owncast -o jsonpath='{.data.admin-password}' | base64 -d
kubectl get secret owncast -o jsonpath='{.data.stream-key}' | base64 -d
```

Point OBS (or ffmpeg) at `rtmp://<host>:1935/live` with the stream key. Viewers watch on the web
player; Owncast transcodes with ffmpeg in the pod and serves HLS.

The chart passes the admin password and stream key as flags on every start, so the Secret stays
the source of truth. Keys added in the admin UI work too.

## Services

`<fullname>` serves the web player, chat, HLS and admin on 8080. `<fullname>-rtmp` takes RTMP on
1935; set `rtmpService.type: LoadBalancer` (or NodePort) to stream from outside the cluster. RTMP
is plain: Owncast has no RTMPS.

## Storage

`/app/data` holds the SQLite database, logs, HLS segments and backups. One replica with
`Recreate`.

## TLS

Owncast serves plain HTTP. With `tls.enabled` a caddy sidecar terminates HTTPS on 8443 (Service
port `service.httpsPort`) and proxies to Owncast over localhost, chat WebSocket included. The
certificate comes from `tls.existingSecret`, else a cert-manager `Certificate`, else a
Helm-generated CA (`ca.crt` in the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/owncast \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `admin.password` / `admin.streamKey` / `admin.existingSecret` | generated | Admin password and stream key |
| `extraArgs` | `[]` | More `owncast` flags |
| `persistence.size` | `5Gi` | The `/app/data` volume |
| `resources` | 250m / 2 CPU | ffmpeg transcoding runs in the pod |
| `service.port` | `8080` | Web Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `rtmpService.type` / `port` | `ClusterIP` / `1935` | RTMP ingest Service |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

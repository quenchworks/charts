# Quenchworks Glance

Hardened [Glance](https://github.com/glanceapp/glance), a self-hosted dashboard that puts feeds,
bookmarks, releases, weather and service status on one page, CVE-gated, cosign-signed and pinned
by digest. The image is one static Go binary built from source on a nonroot Wolfi base.

## Install

```bash
helm install glance oci://ghcr.io/quenchworks/charts/glance
kubectl port-forward svc/glance 8080
```

## Configure

The dashboard is `config`, rendered as `glance.yml` (see the
[configuration docs](https://github.com/glanceapp/glance/blob/main/docs/configuration.md)).
`server.port` is fixed by the chart. Put secrets in a Secret, pass it with
`extraEnvVarsSecret`, and reference them as `${VAR}` in the config:

```yaml
config:
  pages:
    - name: Home
      columns:
        - size: full
          widgets:
            - type: monitor
              sites:
                - title: Grafana
                  url: http://grafana.monitoring:3000/api/health
extraConfigFiles:
  bookmarks.yml: |
    - type: bookmarks
      groups: []
```

Files in `extraConfigFiles` sit beside `glance.yml` in `/app/config`, for `!include:`. A config
change rolls the pods. Glance has no login: keep the Service internal or put an authenticating
proxy in front.

## TLS

Glance serves plain HTTP. With `tls.enabled` a caddy sidecar terminates HTTPS on 8443 (Service
port `service.httpsPort`) and proxies to Glance over localhost. The certificate comes from
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in
the Secret `<fullname>-tls`).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/glance \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `config` | a sample page | `glance.yml` |
| `extraConfigFiles` | `{}` | More files in `/app/config` for `!include` |
| `replicaCount` | `1` | Stateless; scale freely |
| `extraEnvVarsSecret` | `""` | Secret with values for `${VAR}` in the config |
| `service.port` | `8080` | HTTP Service port |
| `service.httpsPort` | `443` | HTTPS Service port, only with `tls.enabled` |
| `tls.enabled` | `false` | caddy sidecar serves HTTPS on 8443 |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate |
| `proxy.image.digest` | (pinned) | the TLS sidecar image |

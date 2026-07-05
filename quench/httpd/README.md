# Quenchworks httpd

Hardened [Apache HTTP Server](https://httpd.apache.org) on a minimal, nonroot,
read-only-rootfs, 0-CVE image pinned by digest. Built from source on Wolfi (no
upstream distro binaries), `mpm_event`. Listens on `8080` (http). Stateless: this
chart runs a `Deployment` and scales horizontally.

## Install

```bash
helm install web oci://ghcr.io/quenchworks/charts/httpd
```

Then reach it from inside the cluster:

```bash
kubectl run web-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl http://web-httpd:8080/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/httpd \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Custom configuration

The image ships a working default config (`ServerRoot /usr`, `DocumentRoot
/usr/share/httpd/htdocs` with an index page, logs to stdout/stderr, all writable
paths under `/tmp`), so no config is required. The shipped `httpd.conf` ends with
`IncludeOptional /etc/httpd/conf.d/*.conf`.

- Serve your own site by mounting content over the doc root
  `/usr/share/httpd/htdocs` via `extraVolumes` / `extraVolumeMounts`.

- Add config by mounting `*.conf` drop-ins into `/etc/httpd/conf.d` the same way,
  e.g. a ConfigMap of virtual-host or reverse-proxy directives:

  ```yaml
  extraVolumes:
    - name: httpd-confd
      configMap:
        name: my-httpd-confd
  extraVolumeMounts:
    - name: httpd-confd
      mountPath: /etc/httpd/conf.d
      readOnly: true
  ```

`/etc/httpd` is read-only in the image; to replace `httpd.conf` wholesale, mount
over it with `extraVolumeMounts`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/httpd` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless; scale freely (ignored when autoscaling is on). |
| `service.port` | `8080` | http (named `http`). |
| `autoscaling.enabled` | `false` | Optional CPU HPA (`minReplicas`/`maxReplicas`). |
| `networkPolicy.enabled` | `true` | Ingress to port 8080. |
| `networkPolicy.allowExternal` | `true` | A web server usually wants external ingress; set `false` to restrict to the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts). Liveness/readiness/startup default to `tcpSocket`
checks on `8080`.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. A writable `emptyDir` is mounted at
`/tmp` for httpd's pid, runtime dir and mutex (the only writable paths the default
config needs). Logs go to stdout/stderr. The NetworkPolicy is the trust boundary.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. No TLS server is configured by
default; TLS is left to the operator (mount certs and a `conf.d` drop-in, or front
with an ingress controller / gateway).

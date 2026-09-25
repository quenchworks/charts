# Quenchworks Eclipse Jetty

[Eclipse Jetty](https://jetty.org) is a lightweight Java web server and servlet
container. This chart runs it on the QuenchWorks jetty image: the official jetty-home
distribution on a Wolfi `openjdk-21-jre`, nonroot, read-only root filesystem, 0 fixable
CVEs, cosign-signed and pinned by digest. It listens on `8080` and is stateless, so the
chart runs a `Deployment` that scales horizontally.

The image carries a ready JETTY_BASE at `/var/lib/jetty` with the http connector and
the Jakarta EE 11 web app deployer (`ee11-deploy`). `webapps/` starts empty, so `GET /`
returns 404 until a web app claims a context.

## Install

```bash
helm install web oci://ghcr.io/quenchworks/charts/jetty
kubectl port-forward svc/web-jetty 8080:8080 &
curl -i http://127.0.0.1:8080/
```

## Deploying applications

Jetty deploys each entry of `/var/lib/jetty/webapps`: a WAR, an unpacked directory, or
a context XML file. Either:

- bake your WAR into a derived image `FROM ghcr.io/quenchworks/images/jetty`, copying
  it into `/var/lib/jetty/webapps/`; or
- mount it there with `extraVolumes` / `extraVolumeMounts`.

Pass JVM flags with `JDK_JAVA_OPTIONS` in `extraEnvVars` (the JVM reads it directly).

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/jetty \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
gh attestation verify oci://ghcr.io/quenchworks/images/jetty --owner quenchworks
```

The release gate installs the chart on kind with a directory web app mounted from a
ConfigMap, and requires Jetty to serve its page with `Server: Jetty(<appVersion>)`,
and an unknown context to return 404.

## Values

| Key                           | Default                             | Notes                                                                                     |
| ----------------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/jetty` |                                                                                           |
| `image.digest`                | (CI-written)                        | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                 | Stateless; scale freely (ignored when autoscaling is on).                                 |
| `service.port`                | `8080`                              | http (named `http`).                                                                      |
| `autoscaling.enabled`         | `false`                             | Optional CPU HPA (`minReplicas`/`maxReplicas`).                                           |
| `networkPolicy.enabled`       | `true`                              | Ingress to port 8080.                                                                     |
| `networkPolicy.allowExternal` | `true`                              | A web server usually wants external ingress; set `false` to restrict to the namespace.    |
| `podDisruptionBudget.enabled` | `true`                              | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                             | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                              | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Probes

Liveness, readiness and startup are `tcpSocket` checks on `8080`: they gate on the
connector accepting, not on an HTTP status, because `GET /` is a 404 until a web app
claims the root context. The startup probe allows about 160s for JVM start and web
app deployment.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. A writable `emptyDir` is mounted at
`/tmp`, which the image sets as `java.io.tmpdir` for unpacked WARs and work files.
Logs go to stdout. The NetworkPolicy is the trust boundary.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

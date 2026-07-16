# Quenchworks Apache Tomcat

Hardened [Apache Tomcat](https://tomcat.apache.org) servlet container / Jakarta EE
web server on a minimal, nonroot, read-only-rootfs, 0-CVE image, cosign-signed (keyless / Sigstore) and pinned by
digest.
Built from source on Wolfi (`openjdk-21-jre`, no upstream distro binaries). Listens
on `8080` (http). Stateless: this chart runs a `Deployment` and scales horizontally.

The default `ROOT` webapp is emptied, so `GET /` returns **404** on a fresh install —
that is expected and healthy (Coyote is up and answering; there is just no app to
serve). Deploy your own WAR to change this.

## Install

```bash
helm install web oci://ghcr.io/quenchworks/charts/tomcat
```

Then reach it from inside the cluster (a 404 confirms Tomcat is up):

```bash
kubectl run web-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://web-tomcat:8080/
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/tomcat \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/tomcat --owner quenchworks`.

## Deploying applications

The image ships stock Tomcat with an emptied `ROOT` webapp. Deploy applications by:

- Baking your WAR into a derived image `FROM ghcr.io/quenchworks/images/tomcat`,
  copying it into the Tomcat `webapps/` directory; or
- Mounting a WAR (or an exploded app) into the `webapps/` directory via
  `extraVolumes` / `extraVolumeMounts`.

Set JVM options through `extraEnvVars` (for example `JAVA_OPTS`, `CATALINA_OPTS`).

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/tomcat` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless; scale freely (ignored when autoscaling is on). |
| `service.port` | `8080` | http (named `http`). |
| `autoscaling.enabled` | `false` | Optional CPU HPA (`minReplicas`/`maxReplicas`). |
| `networkPolicy.enabled` | `true` | Ingress to port 8080. |
| `networkPolicy.allowExternal` | `true` | A web server usually wants external ingress; set `false` to restrict to the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Probes

Liveness, readiness and startup are `tcpSocket` checks on `8080` — they gate on
Coyote accepting the connection, **not** on an HTTP status, because `GET /` is a
404 by design. The startup probe is generous (up to ~160s) to cover JVM +
Catalina boot before liveness/readiness kick in.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. A writable `emptyDir` is mounted at
`/tmp` for Tomcat's logs, temp and work dirs (under `/tmp/tomcat`). Logs go to
stdout/stderr. The NetworkPolicy is the trust boundary.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

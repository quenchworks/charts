# Selenium Grid

[Selenium Grid](https://www.selenium.dev/documentation/grid/) runs WebDriver sessions on
remote browsers. This chart deploys Selenium Grid 4 in hub-and-node mode: one hub (the
router, distributor, session queue and event bus in one process) and a Deployment of
headless Firefox nodes that register with it. Both images are QuenchWorks builds of the
upstream `selenium-server` jar on a Wolfi JRE; the Firefox node adds Wolfi Firefox and
geckodriver. They run nonroot, are CVE-gated, cosign-signed and pinned by digest.

## Install

```sh
helm install grid oci://ghcr.io/quenchworks/charts/selenium-grid
kubectl port-forward svc/grid-selenium-grid-hub 4444:4444
curl http://127.0.0.1:4444/status
```

Point any WebDriver client at `http://<release>-selenium-grid-hub:4444`. The Grid UI is
at `/ui`.

## Firefox nodes

Each node pod offers one Firefox session (headless, no display server). Scale with
`firefox.replicas`; requests beyond the free slots wait in the hub's queue for
`hub.sessionRequestTimeout` seconds, then fail with "session not created". Firefox gets
a memory-backed `/dev/shm` of `firefox.shmSize`.

A node registers through the hub's event bus (ports 4442 and 4443 on the hub Service)
and advertises its pod IP; the hub then talks to it on port 5555.

There is no Chromium node yet: the Wolfi chromium build carries an unfixed CRITICAL CVE,
so it waits for a fixed release.

## Security

The hub has no authentication. Keep the Service internal, or put an authenticating
proxy in front of `ingress`. Browsers run as uid 1001 on a read-only root filesystem
with every capability dropped.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` / `image.digest` | QuenchWorks selenium-server | Hub image, pinned by digest |
| `hub.sessionRequestTimeout` | `300` | Seconds a new-session request waits for a free slot |
| `hub.extraArgs` / `hub.extraEnvVars` | `[]` | Extra hub flags and env (`JAVA_TOOL_OPTIONS` for JVM flags) |
| `hub.resources` | 100m/512Mi, 1/1Gi | Hub requests and limits |
| `service.type` / `service.port` | `ClusterIP` / `4444` | Hub Service (4442/4443 are always exposed for the event bus) |
| `tls.enabled` | `false` | the hub's 4444 serves HTTPS only (PKCS#8 key); nodes register over https and trust the chart CA; event bus and 5555 stay plain in the release |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice); it must name the hub Service |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice); the hub Service names are added |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |
| `openssl.digest` | pinned | helper image for the PKCS#8 key and the node truststore |
| `firefox.enabled` | `true` | Deploy Firefox nodes |
| `firefox.image.repository` / `firefox.image.digest` | QuenchWorks selenium-node-firefox | Node image, pinned by digest |
| `firefox.replicas` | `1` | Node pods, one Firefox session each |
| `firefox.shmSize` | `512Mi` | Size of the memory-backed `/dev/shm` |
| `firefox.extraArgs` / `firefox.extraEnvVars` | `[]` | Extra node flags and env |
| `firefox.resources` | 250m/1Gi, 1/2Gi | Node requests and limits |
| `ingress.*` | disabled | Optional Ingress to the hub |
| `nodeSelector`, `affinity`, `tolerations`, `podSecurityContext`, `containerSecurityContext` | | Applied to hub and node pods |

## License

Selenium is Apache-2.0. This chart is Apache-2.0.

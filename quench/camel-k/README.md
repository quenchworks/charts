# QuenchWorks Camel K

[Apache Camel K](https://camel.apache.org/camel-k/) builds and runs Apache Camel
integrations on Kubernetes from custom resources: `Integration`, `Pipe`,
`Kamelet`, `IntegrationKit`, `Build` and `IntegrationPlatform`. This chart
installs the Camel K 2.11.0 operator and its CRDs (in `crds/`). The operator
image is nonroot, 0 fixable CVEs, pinned by digest and cosign-signed. It is
`kamel` built from source on Wolfi OpenJDK 17 and Maven 3.9: integration builds
run inside the operator pod (Maven, then Jib), so the toolchain that compiles
your routes is the scanned one, and nothing downloads a Maven distribution at
runtime.

## Install

Camel K pushes every integration image to a container registry, so set one:

```bash
helm install camel-k oci://ghcr.io/quenchworks/charts/camel-k \
  -n camel-k --create-namespace \
  --set registry.address=registry.example.com \
  --set registry.secret=my-registry-credentials
```

Then run an integration in the same namespace:

```yaml
apiVersion: camel.apache.org/v1
kind: Integration
metadata:
  name: hello
spec:
  flows:
    - from:
        uri: "timer:tick?period=5000"
        steps:
          - setBody:
              constant: "Hello from Camel K"
          - to: "log:info"
```

The first build downloads the Camel and Quarkus artifacts from Maven Central
into the operator's local repository (an `emptyDir`), so it takes a few minutes.

## Values

| Key | Default | Notes |
|---|---|---|
| `registry.address` | `""` | registry integration images are pushed to; required on Kubernetes |
| `registry.insecure` | `false` | plain HTTP registry (testing only) |
| `registry.secret` | `""` | Secret with registry credentials |
| `registry.organization` | `""` | repository prefix in the registry |
| `watchAnyNamespace` | `false` | `false` watches the release namespace only (Role) |
| `operatorId` | `camel-k` | value of the `camel.apache.org/operator.id` annotation it owns |
| `logLevel` | `info` | `debug`, `info` or `error` |
| `resources` | 512Mi to 2Gi | builds run in the operator pod; Maven needs the headroom |
| `extraEnvVars` | `[]` | further operator settings (`MAVEN_REPOSITORIES`, `BUILD_TIMEOUT_SECONDS`, ...) |

## Notes

- **Configure by env, not by IntegrationPlatform.** Camel K 2.11 deprecates the
  `IntegrationPlatform` resource in favour of operator environment variables,
  which is what the `registry.*` values set. An `IntegrationPlatform` you create
  does not inherit them, and its create step fails while a `CamelCatalog` for
  its runtime already exists, so create it before the first build or not at all.
- **Integration pods run upstream's base image.** Jib layers each integration on
  `eclipse-temurin:21-jdk` (the operator default); set `BUILD_BASE_IMAGE` in
  `extraEnvVars` to use another JDK image, for example the QuenchWorks `jre`.
- The kubelet must be able to pull from `registry.address`. An in-cluster
  registry reached by a Service name works for the push, not for the pull.
- Helm installs CRDs from `crds/` but never upgrades them. Apply the new
  `crds/camel-k-crds.yaml` by hand when you upgrade the chart.

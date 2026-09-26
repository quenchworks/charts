# Quenchworks WildFly

[WildFly](https://www.wildfly.org) is the Jakarta EE application server. This chart
runs it on the QuenchWorks wildfly image: the official distribution on a Wolfi
openjdk-21 JRE, nonroot (uid 1001), read-only root filesystem, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install app oci://ghcr.io/quenchworks/charts/wildfly
kubectl port-forward svc/app-wildfly 8080:8080
```

## Deploying applications

The entrypoint makes `/tmp/wildfly` (an emptyDir) the server base and copies
`/opt/wildfly/standalone/deployments` into it at every start. Two ways to get a WAR
or EAR there:

- **A derived image** (recommended):

  ```dockerfile
  FROM ghcr.io/quenchworks/images/wildfly@sha256:...
  COPY target/app.war /opt/wildfly/standalone/deployments/
  ```

- **A mount**, with `extraVolumes` and `extraVolumeMounts` (a PVC, or a ConfigMap for
  a small WAR):

  ```yaml
  extraVolumes:
    - name: app
      persistentVolumeClaim: { claimName: my-app-war }
  extraVolumeMounts:
    - name: app
      mountPath: /opt/wildfly/standalone/deployments/app.war
      subPath: app.war
  ```

## Values

| Key | Default | Meaning |
|---|---|---|
| `serverConfig` | `standalone.xml` | passed as `-c`; also `standalone-full.xml`, `standalone-microprofile.xml`, the `-ha` variants |
| `javaOpts` | `""` | `JAVA_OPTS`; empty keeps standalone.conf's defaults, set it and you replace them (include heap size) |
| `extraArgs` | `[]` | extra server arguments, e.g. `-Dmy.prop=value` |
| `probePath` | `/` | HTTP path the probes hit on 8080 |
| `replicaCount` / `autoscaling.*` | `1` / off | stateless, scale freely |

To change the server configuration permanently, mount your own file over
`/opt/wildfly/standalone/configuration/<name>.xml`. The entrypoint copies the
configuration to `/tmp` at each start, so CLI changes last only until the pod
restarts.

The management interface (9990, CLI and console) stays on loopback:
`kubectl exec -it deploy/app-wildfly -- /opt/wildfly/bin/jboss-cli.sh --connect`.

## Release gate

On kind, the gate mounts a one-JSP WAR from a ConfigMap, the same way the README
shows. The JSP must compute `quench-42` on the server. The gate also requires a
clean boot (WFLYSRV0025, not "started with errors"), the chart's appVersion, the
welcome page, and uid 1001.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

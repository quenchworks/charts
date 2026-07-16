# Quenchworks Jenkins

Hardened [Jenkins](https://github.com/jenkinsci/jenkins) (the leading open-source
automation server for CI/CD pipelines and Pipeline-as-Code) on a minimal, nonroot,
0-CVE image, pinned by digest and cosign-signed.

## Install

```sh
helm install jenkins oci://ghcr.io/quenchworks/charts/jenkins
```

Jenkins runs nonroot on a read-only root filesystem as a single-replica StatefulSet,
with all of its state (`JENKINS_HOME`) on a persistent `/var/jenkins_home` volume.
The image entrypoint is `java -jar /usr/share/jenkins/jenkins.war --httpPort=8080`.

## Ports

| Port | Name | Purpose |
|------|------|---------|
| `8080` | `http` | web UI + REST API + `/login` |
| `50000` | `agent` | inbound JNLP/TCP build agents |

Liveness/readiness probe `GET /login` on the http port (`8080`); it returns 200 once
the servlet container is up (~15-40s after start), so the probes use a generous
`initialDelaySeconds` and failure budget.

```sh
kubectl port-forward svc/jenkins-jenkins 8080:8080
curl http://127.0.0.1:8080/login      # 200 once Jenkins is up
# browse http://127.0.0.1:8080
```

## First boot / setup wizard

This is the **core** Jenkins image (no bundled plugins). By default the chart sets
`JAVA_OPTS=-Djenkins.install.runSetupWizard=false` (via `extraEnvVars`), so Jenkins
boots straight to a usable state with the setup wizard skipped — convenient for an
internal/sandbox install, but it leaves **no authentication** configured. Configure
security under *Manage Jenkins > Security* before exposing it.

To run the guided first-boot setup instead, drop the `runSetupWizard` flag from
`extraEnvVars` and read the generated unlock secret:

```sh
kubectl exec sts/jenkins-jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```

Plugins install into `JENKINS_HOME` at runtime (via *Manage Jenkins > Plugins* or
Configuration-as-Code) and persist on the volume.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/jenkins` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | controller is single-instance; scale build capacity with agents |
| `persistence.enabled` | `true` | volumeClaimTemplate at `/var/jenkins_home` |
| `persistence.size` | `8Gi` | |
| `persistence.existingClaim` | `""` | reuse a pre-created PVC |
| `service.type` | `ClusterIP` | |
| `service.ports.http` | `8080` | web UI + REST + `/login` |
| `service.ports.agent` | `50000` | inbound JNLP agents |
| `extraEnvVars` | `JAVA_OPTS=-Djenkins.install.runSetupWizard=false` | tune the JVM / disable the wizard |

### Production notes

- The image entrypoint hardcodes `--httpPort=8080`; change `service.ports.http`
  only to remap the Service, not the container port.
- The root filesystem is read-only. `JENKINS_HOME` (the PVC) and an emptyDir at
  `/tmp` are the only writable paths; mount additional writable paths via
  `extraVolumes` / `extraVolumeMounts` if a plugin needs them.
- Tune the JVM (heap, GC) via `JAVA_OPTS` in `extraEnvVars`.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/jenkins \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/jenkins --owner quenchworks`.

## Uninstall

```sh
helm uninstall jenkins
```

The PVC provisioned by the `volumeClaimTemplate` (holding `JENKINS_HOME`) is
retained by Kubernetes on uninstall. Delete it explicitly if you want all Jenkins
state gone:

```sh
kubectl delete pvc -l app.kubernetes.io/instance=jenkins
```

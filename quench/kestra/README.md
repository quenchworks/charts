# Kestra

[Kestra](https://kestra.io), a declarative event-driven orchestration platform: YAML flows, schedules and triggers, a
plugin catalog, a web UI and an API. It runs standalone (web server, scheduler, executor and worker in one process) on
the bundled PostgreSQL. The image is QuenchWorks' build of the release jar with its vulnerable shaded library rebuilt,
CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install kestra oci://ghcr.io/quenchworks/charts/kestra
kubectl get secret kestra -o jsonpath='{.data.admin-password}' | base64 -d
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.username`, `admin.password` | `admin@kestra.local`, generated | The basic-auth admin (an email address; 8+ characters with upper, lower and a digit). |
| `publicUrl` | `""` | Kestra's URL as users reach it. |
| `postgresql.enabled` / `externalDatabase.*` | bundled | PostgreSQL for the repository and the queue. |
| `persistence.*` | 10Gi RWO | Flow storage (local). One replica. |
| `javaOpts` | `""` | `JAVA_OPTS`. |
| `extraEnvVars` | `[]` | Any other setting as an environment variable (Micronaut maps `KESTRA_*`). |

Plugin auto-install and the tutorial flows are off: with them on, Kestra downloads plugin jars from Maven at runtime,
outside the image's CVE gate. Plain HTTP: put an Ingress with TLS in front.

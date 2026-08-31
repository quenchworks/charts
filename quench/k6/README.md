# Quenchworks k6

Hardened [k6](https://github.com/grafana/k6), Grafana's developer-friendly load and
performance testing tool scripted in JavaScript, on a minimal, nonroot, 0-CVE image
built from source, cosign-signed and pinned by digest.

**k6 is a CLI, not a server.** It runs a script, reports, and exits. So this chart
creates a **Job** (run once) or a **CronJob** (run on a schedule) — never a
Deployment. A Deployment would restart k6 forever, re-running your load test in a
loop against whatever it targets, which is how a test tool becomes an outage.

## Install

```bash
helm install loadtest oci://ghcr.io/quenchworks/charts/k6
```

The bundled default script makes **no network calls** — it only proves the k6 runtime
executes a script and exits 0. A chart's default behaviour must not generate load
against anything. Replace it with your own test:

```bash
helm install loadtest oci://ghcr.io/quenchworks/charts/k6 \
  --set-file script=./my-test.js \
  --set vus=50 --set duration=2m
```

Watch the run and read the summary from the pod log:

```bash
kubectl logs -l app.kubernetes.io/instance=loadtest --tail=-1
```

Run it on a schedule instead:

```bash
helm install nightly oci://ghcr.io/quenchworks/charts/k6 \
  --set mode=cronjob --set cronjob.schedule='0 2 * * *' \
  --set-file script=./my-test.js
```

`cronjob.concurrencyPolicy` defaults to `Forbid`, so two load tests never overlap.

### Using it as a release gate

`helm install --wait` blocks until the Job finishes, so a failing test fails the
release — usually what you want in CI. To run k6 as a Helm hook instead of leaving
the Job in the release, set `job.helmHook`:

```bash
helm upgrade --install api ./my-chart --wait
helm install gate oci://ghcr.io/quenchworks/charts/k6 \
  --set job.helmHook=post-install,post-upgrade \
  --set-file script=./smoke.js
```

`job.backoffLimit` is `0` on purpose: a failed load test is a **result**, not a flake
to retry.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/k6 \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/k6 --owner quenchworks`.

## Values

| Key                                | Default                         | Notes                                                                                              |
| ---------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------- |
| `image.repository`                 | `ghcr.io/quenchworks/images/k6` |                                                                                                    |
| `image.digest`                     | (CI-written)                    | Required. Charts pin by digest, never a tag.                                                       |
| `image.pullPolicy`                 | `IfNotPresent`                  |                                                                                                    |
| `nameOverride`                     | `""`                            | Override the chart name in resource names.                                                         |
| `fullnameOverride`                 | `""`                            |                                                                                                    |
| `mode`                             | `job`                           | `job` (run once on install) or `cronjob` (scheduled).                                               |
| `script`                           | (trivial no-network check)      | Test script, rendered into a ConfigMap and mounted read-only. Use `--set-file`.                     |
| `existingConfigMap`                | `""`                            | Mount a script you manage elsewhere; its key must equal `scriptFileName`.                           |
| `scriptFileName`                   | `script.js`                     | Filename under `/scripts`.                                                                         |
| `args`                             | `[run, /scripts/script.js]`     | Arguments after `k6`; the image entrypoint is the k6 binary.                                        |
| `vus`                              | `null`                          | `--vus`, virtual users.                                                                            |
| `duration`                         | `""`                            | `--duration`, e.g. `30s`.                                                                          |
| `extraArgs`                        | `[]`                            | Extra k6 flags, e.g. `["--out","json=/dev/stdout"]`.                                               |
| `job.backoffLimit`                 | `0`                             | A failed load test is a result, not a flake to retry.                                              |
| `job.activeDeadlineSeconds`        | `null`                          | Hard wall-clock cap on the run.                                                                    |
| `job.ttlSecondsAfterFinished`      | `null`                          | Let the cluster reap finished Jobs.                                                                |
| `job.helmHook`                     | `""`                            | e.g. `post-install,post-upgrade` to run k6 as a release gate instead of a plain Job.                |
| `cronjob.schedule`                 | `0 * * * *`                     |                                                                                                    |
| `cronjob.concurrencyPolicy`        | `Forbid`                        | Never let two load tests overlap.                                                                  |
| `cronjob.successfulJobsHistoryLimit` | `3`                           |                                                                                                    |
| `cronjob.failedJobsHistoryLimit`   | `3`                             |                                                                                                    |
| `cronjob.suspend`                  | `false`                         |                                                                                                    |
| `cronjob.startingDeadlineSeconds`  | `null`                          |                                                                                                    |
| `api.enabled`                      | `false`                         | k6's REST API (`--address`). **Unauthenticated** — only useful to control a long run externally.    |
| `api.port`                         | `6565`                          |                                                                                                    |
| `resources.requests`               | `cpu 200m / mem 256Mi`          | Load generation is CPU-bound; raise both for meaningful VU counts.                                 |
| `resources.limits`                 | `cpu 1 / mem 1Gi`               |                                                                                                    |
| `serviceAccount.create`            | `true`                          |                                                                                                    |
| `serviceAccount.automountServiceAccountToken` | `false`              | k6 never talks to the API server.                                                                  |
| `networkPolicy.enabled`            | `false`                         | k6 exists to send traffic **out**; a default-deny egress policy would break every test.            |

Plus the shared `quench-common` knobs: `partOf`, `commonLabels`, `commonAnnotations`,
`podLabels`, `podAnnotations`, `selectorLabels`, `imagePullSecrets`, `nodeSelector`,
`affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`,
`schedulerName`, `terminationGracePeriodSeconds`, `extraEnvVars`, `extraEnvVarsCM`,
`extraEnvVarsSecret`, `extraVolumes`, `extraVolumeMounts`, `initContainers`,
`sidecars`.

## Licence

k6 is **AGPL-3.0-only**. The chart and image packaging are MIT; the upstream licence
governs the software itself.

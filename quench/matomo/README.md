# Quenchworks Matomo

Hardened [Matomo](https://github.com/matomo-org/matomo), the self-hosted,
privacy-respecting web analytics platform where you keep the raw data, on a minimal,
nonroot, 0-CVE image built from source, cosign-signed and pinned by digest. Runs
nginx + php-fpm from a single image as a Deployment and serves the UI on port 8080.

**Bring your own MySQL or MariaDB.** No database subchart is bundled — pair this with
`oci://ghcr.io/quenchworks/charts/mariadb` or point it at a managed instance.

## Install

```bash
helm install analytics oci://ghcr.io/quenchworks/charts/matomo \
  --set externalDatabase.host=mariadb.data.svc.cluster.local \
  --set externalDatabase.database=matomo \
  --set externalDatabase.user=matomo
```

Then reach the UI and **complete the web installer once**:

```bash
kubectl port-forward svc/analytics-matomo 8080:8080
# open http://127.0.0.1:8080
```

### Why you have to run the installer

Matomo has **no environment-variable configuration**. Everything lives in
`config.ini.php`, which its web installer generates on first run. The chart therefore
cannot pre-seed credentials for you.

That also means the `externalDatabase.*` values are **not read by the pod at boot** —
they are what you type *into* the installer, recorded here so the values file
documents the intended target and `NOTES.txt` can print it back to you. In
particular, setting `externalDatabase.password` buys you nothing and leaks the
password into `helm get values`; prefer leaving it empty and typing it in the
installer.

### Persistence is not optional in practice

`config/` holds `config.ini.php`, the installer's output. With
`persistence.enabled=false`, Matomo asks you to reinstall on **every pod restart**,
and each previous install is orphaned against a database that already has its schema.
The chart defaults to a 1Gi ReadWriteOnce PVC.

### One replica, deliberately

`replicaCount` is `1` and is not a knob to turn up casually. The installer writes into
a ReadWriteOnce volume, so a second replica on another node cannot mount it — and two
replicas sharing one config while each runs its own archiving cron would
double-process the same data. Scale by giving the pod more CPU, or move `config/` to a
ReadWriteMany volume first.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/matomo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/matomo --owner quenchworks`.

## Values

| Key                            | Default                             | Notes                                                                                          |
| ------------------------------ | ----------------------------------- | ---------------------------------------------------------------------------------------------- |
| `image.repository`             | `ghcr.io/quenchworks/images/matomo` |                                                                                                |
| `image.digest`                 | (CI-written)                        | Required. Charts pin by digest, never a tag.                                                   |
| `image.pullPolicy`             | `IfNotPresent`                      |                                                                                                |
| `nameOverride`                 | `""`                                | Override the chart name in resource names.                                                     |
| `fullnameOverride`             | `""`                                |                                                                                                |
| `replicaCount`                 | `1`                                 | See "One replica, deliberately" above.                                                         |
| `matomo.port`                  | `8080`                              | Container port (nonroot, so not 80).                                                           |
| `externalDatabase.host`        | `""`                                | MySQL/MariaDB host. Typed into the installer, not read at boot.                                |
| `externalDatabase.port`        | `3306`                              |                                                                                                |
| `externalDatabase.database`    | `matomo`                            |                                                                                                |
| `externalDatabase.user`        | `matomo`                            |                                                                                                |
| `externalDatabase.password`    | `""`                                | Only printed in NOTES for the installer. Leave empty — it leaks into `helm get values`.        |
| `persistence.enabled`          | `true`                              | Holds `config.ini.php`. Disabling it means reinstalling on every restart.                       |
| `persistence.size`             | `1Gi`                               |                                                                                                |
| `persistence.accessModes`      | `["ReadWriteOnce"]`                 |                                                                                                |
| `persistence.existingClaim`    | `""`                                | Use a PVC you manage.                                                                          |
| `persistence.storageClass`     | (cluster default)                   |                                                                                                |
| `service.type`                 | `ClusterIP`                         | `ClusterIP`, `NodePort`, or `LoadBalancer`.                                                    |
| `service.port`                 | `8080`                              |                                                                                                |
| `resources.requests`           | `cpu 200m / mem 512Mi`              |                                                                                                |
| `resources.limits`             | `cpu 1 / mem 1Gi`                   |                                                                                                |
| `serviceAccount.create`        | `true`                              |                                                                                                |
| `serviceAccount.automountServiceAccountToken` | `false`              | Matomo never talks to the API server.                                                          |
| `rbac.create`                  | `false`                             |                                                                                                |
| `networkPolicy.enabled`        | `true`                              |                                                                                                |
| `networkPolicy.allowExternal`  | `true`                              | Analytics must accept beacons from wherever your sites are served — unlike a datastore.         |
| `podDisruptionBudget.enabled`  | `false`                             |                                                                                                |
| `ingress.enabled`              | `false`                             | Set `ingress.hosts` and `ingress.className` to expose the UI.                                  |

Plus the shared `quench-common` knobs: `partOf`, `commonLabels`, `commonAnnotations`,
`podLabels`, `podAnnotations`, `selectorLabels`, `imagePullSecrets`, `nodeSelector`,
`affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`,
`schedulerName`, `terminationGracePeriodSeconds`, `updateStrategy`, the probe
overrides, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`, `extraVolumes`,
`extraVolumeMounts`, `initContainers`, `sidecars`.

## Licence

Matomo is **GPL-3.0-or-later**. The chart and image packaging are MIT; the upstream
licence governs the software itself.

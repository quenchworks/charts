# Quenchworks reloader

Hardened [Stakater Reloader](https://github.com/stakater/Reloader) on a minimal,
nonroot, 0-CVE image, built from source and pinned by digest.

Reloader watches ConfigMaps and Secrets and rolls the Deployments, StatefulSets
and DaemonSets that use them, so a changed config reaches running pods without a
manual restart.

## Install

```sh
helm install reloader oci://ghcr.io/quenchworks/charts/reloader
```

Then opt a workload in with an annotation on its Deployment, StatefulSet or
DaemonSet:

```yaml
metadata:
  annotations:
    reloader.stakater.com/auto: "true"                  # any ConfigMap or Secret it uses
    # configmap.reloader.stakater.com/reload: "a,b"     # only these ConfigMaps
    # secret.reloader.stakater.com/reload: "c"          # only these Secrets
```

The default strategy adds a `STAKATER_<NAME>_CONFIGMAP` (or `_SECRET`) variable
holding the content hash to the pod template, which starts a normal rollout.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/reloader \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/reloader --owner quenchworks`.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `watchGlobally` | `true` | Watch every namespace (ClusterRole). `false` watches the release namespace only, with a namespaced Role. |
| `namespacesToIgnore` | `[]` | Global mode: namespaces to skip. |
| `namespaceSelector` | `[]` | Global mode: only namespaces with these labels, as `key:value`. Adds namespaces read access. |
| `autoReloadAll` | `false` | Reload every workload without the opt-in annotation. |
| `resourcesToIgnore` | `[]` | `configmaps` or `secrets`, to stop watching one kind. |
| `logLevel`, `logFormat` | `info`, text | `logFormat: json` for structured logs. |
| `extraArgs` | `[]` | Appended to the `reloader` command line. |
| `service.enabled` | `true` | ClusterIP Service for `/metrics` on 9090. |
| `networkPolicy.enabled` | `true` | Ingress to 9090 from the release namespace only (`allowExternal: true` opens it). |

Reloader writes a `reloader-meta-info` ConfigMap in its namespace describing the
options it started with; the chart grants exactly that through a namespaced Role.

## High availability

```yaml
replicaCount: 2
leaderElection:
  enabled: true
podDisruptionBudget:
  enabled: true
```

Every replica watches; only the holder of the `stakater-reloader-lock` lease
reloads. A replica that loses the lease fails `/live` and is restarted.

## Metrics

`reloader_reload_executed_total{success="true|false"}` counts reloads on
`:9090/metrics`.

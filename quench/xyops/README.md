# Quenchworks xyOps

Hardened [xyOps](https://github.com/pixlcore/xyops) on a minimal, nonroot,
read-only-rootfs, 0-CVE image, pinned by digest and cosign-signed.

xyOps is a complete workflow-automation and server-monitoring system — a job
scheduler, host/service monitors, alerting and ticketing — by Joseph Huckaby, the
creator of Cronicle. It stores all of its state in an **embedded better-sqlite3
database**, so there is no external database to run. Licensed **BSD-3-Clause**.

## Install

```sh
helm install xyops oci://ghcr.io/quenchworks/charts/xyops
```

The server runs nonroot and serves the web UI + JSON API on container port 5522;
the Service exposes it on the same port.

```sh
kubectl port-forward svc/xyops-xyops 5522:5522
curl http://127.0.0.1:5522/api/app/ping
# then browse http://127.0.0.1:5522/
```

## Signing secret

xyOps requires a non-empty `secret_key` to boot (it signs sessions and API
tokens). The chart delivers it via the `XYOPS_secret_key` env var from a Secret:

- Set `auth.existingSecret` (and `auth.existingSecretKey`) to use your own Secret.
- Set `auth.secretKey` to pin a fixed value.
- Leave both empty and the chart generates a random key on first install and
  preserves it across upgrades.

Nothing secret is baked into the image.

## Storage & scaling

This is a stateful, **single-instance** workload. The chart runs a single-replica
**StatefulSet** and mounts a persistent volume at `/opt/xyops/data` (the sqlite
store) via a `volumeClaimTemplate`, so state survives restarts. The read-only
rootfs is paired with writable `emptyDir`s for `/opt/xyops/logs`,
`/opt/xyops/temp` and `/tmp`; the hardened pod security context (`fsGroup: 1001`)
gives the nonroot user (uid 1001) ownership of the data volume.

The embedded sqlite store does not support horizontal scaling — do not raise the
replica count.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/xyops` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `auth.secretKey` | `""` | pin the signing key; random if empty |
| `auth.existingSecret` | `""` | read `secret_key` from your own Secret |
| `auth.existingSecretKey` | `secret-key` | key within `existingSecret` |
| `resources.requests` | `cpu 100m / memory 256Mi` | raise for more monitored hosts/jobs |
| `resources.limits` | `cpu 1 / memory 1Gi` | |
| `persistence.enabled` | `true` | `/opt/xyops/data` PVC; `false` uses an ephemeral emptyDir |
| `persistence.size` | `8Gi` | grow as history accumulates |
| `persistence.existingClaim` | `""` | bind an existing PVC instead of provisioning one |
| `extraEnvVars` | `[]` | e.g. `XYOPS_base_app_url` to set the external URL |
| `service.type` | `ClusterIP` | |
| `service.port` | `5522` | web UI + API |

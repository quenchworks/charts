# Quenchworks Mosquitto

Hardened [Eclipse Mosquitto](https://mosquitto.org) — the lightweight open-source
MQTT broker (MQTT 3.1 / 3.1.1 / 5.0 over TCP, TLS and websockets) — on a minimal,
nonroot, 0-CVE image, pinned by digest. It runs as a single-replica Deployment on
a read-only root filesystem with all capabilities dropped. The image is
cosign-signed (keyless / Sigstore) and the chart pins it by the signed digest,
never a tag.

## Install

```bash
helm install mosquitto oci://ghcr.io/quenchworks/charts/mosquitto
```

Mosquitto runs nonroot as a single-replica Deployment (the open-source broker has
no native clustering). The chart renders `mosquitto.conf` into a ConfigMap and
mounts it over `/etc/mosquitto/mosquitto.conf`, and keeps retained messages +
session state on a PersistentVolumeClaim at `/mosquitto/data`.

Publish/subscribe with the bundled clients:

```bash
kubectl exec deploy/mosquitto-mosquitto -- mosquitto_sub -t 'demo/#' -C 1 &
kubectl exec deploy/mosquitto-mosquitto -- mosquitto_pub -t demo/hello -m 'hi'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/mosquitto \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/mosquitto --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mosquitto` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent`, or `Never`. |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Broker is single-instance (no OSS clustering). |
| `updateStrategy.type` | `Recreate` | Avoids two pods contending for the RWO PVC. |
| `config.conf` | anonymous `1883` | Inline `mosquitto.conf`, rendered into a ConfigMap and mounted over the image default. |
| `config.existingConfigMap` | `""` | Use your own ConfigMap (key `mosquitto.conf`) instead; wins over `config.conf`. |
| `persistence.enabled` | `true` | PVC at `/mosquitto/data` (retained messages + session DB). `false` = ephemeral `emptyDir`. |
| `persistence.size` | `1Gi` | Requested volume size. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `resources.requests` | `cpu 50m / mem 32Mi` | |
| `resources.limits` | `cpu 500m / mem 256Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.ports.mqtt` | `1883` | MQTT listener. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress. |
| `networkPolicy.allowExternal` | `true` | MQTT clients usually connect across the cluster; set `false` to restrict to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts). The chart already wires a
writable `/tmp` `emptyDir` for the broker pid on the read-only rootfs.

## Architecture

A single-replica Deployment runs the broker behind a ClusterIP Service. Only the
MQTT listener on **`1883`** is exposed by default:

| Port | Name | Purpose |
|------|------|---------|
| `1883` | `mqtt` | MQTT 3.1 / 3.1.1 / 5.0 |

The image also supports an `8883` MQTT-over-TLS listener and an `8080` websockets
listener — enable them in `config.conf` (and add `service.ports`) to expose them.
Liveness and readiness use a TCP connect to `1883` (the broker has no HTTP health
endpoint).

Retained messages and session state persist on a `ReadWriteOnce` PVC at
`/mosquitto/data`, so the update strategy is `Recreate` to avoid two pods
contending for the volume. The container runs nonroot on a read-only root
filesystem with all capabilities dropped; the pid file lives under a writable
`/tmp` `emptyDir`.

## Configuration examples

Set `config.conf` to a full [mosquitto.conf](https://mosquitto.org/man/mosquitto-conf-5.html),
or point `config.existingConfigMap` at an externally-managed ConfigMap (key
`mosquitto.conf`) to manage it out of band.

### Production note: the default allows anonymous access

The default config enables an anonymous listener on `1883` for a zero-config
bring-up. **For production, turn this off** (`allow_anonymous false`) and add
authentication:

- A `password_file` — generate hashes with `mosquitto_passwd` (bundled in the
  image), mount the file via `extraVolumes`/`extraVolumeMounts`, and reference it
  in `config.conf`.
- A TLS listener on `8883` — mount certs and add `listener 8883` + `cafile` /
  `certfile` / `keyfile` directives.
- Fine-grained ACLs via the bundled `dynamic-security` plugin, or an `acl_file`.

An authenticated broker with persistence:

```yaml
config:
  conf: |
    pid_file /tmp/mosquitto.pid
    persistence true
    persistence_location /mosquitto/data/
    log_dest stdout
    listener 1883
    allow_anonymous false
    password_file /mosquitto/auth/passwords
    include_dir /etc/mosquitto/conf.d
extraVolumes:
  - name: auth
    secret: { secretName: mosquitto-passwords }
extraVolumeMounts:
  - name: auth
    mountPath: /mosquitto/auth
    readOnly: true
```

## Uninstall

```bash
helm uninstall mosquitto
```

The PVC is retained by Kubernetes on uninstall — delete it explicitly if you want
the retained messages and session state gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=mosquitto
```

## Notes

Single instance (the open-source broker has no native clustering). Depends on the
`quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. The container runs as nonroot on
a read-only root filesystem with all capabilities dropped, and the image is pinned
by digest. The default config allows anonymous access for bring-up — add
authentication and keep the NetworkPolicy as the trust boundary before exposing
the broker.

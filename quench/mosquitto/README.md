# Quenchworks Mosquitto

Hardened [Eclipse Mosquitto](https://mosquitto.org) (the lightweight open-source
MQTT broker) on a minimal, nonroot, 0-CVE image, pinned by digest and
cosign-signed.

## Install

```sh
helm install mosquitto oci://ghcr.io/quenchworks/charts/mosquitto
```

Mosquitto runs nonroot on a read-only root filesystem as a single-replica
Deployment (the open-source broker has no native clustering). The chart renders
`mosquitto.conf` into a ConfigMap and mounts it over `/etc/mosquitto/mosquitto.conf`,
and keeps retained messages + session state on a PersistentVolumeClaim at
`/mosquitto/data`.

## Ports

| Port | Name | Purpose |
|------|------|---------|
| `1883` | `mqtt` | MQTT 3.1 / 3.1.1 / 5.0 |

The image also supports an `8883` MQTT-over-TLS listener and an `8080` websockets
listener — enable them in `config.conf` (and add `service.ports`) to expose them.
Liveness/readiness use a TCP connect to `1883` (the broker has no HTTP health
endpoint).

Publish/subscribe over a port-forward with the bundled clients:

```sh
kubectl exec deploy/mosquitto-mosquitto -- mosquitto_sub -t 'demo/#' -C 1 &
kubectl exec deploy/mosquitto-mosquitto -- mosquitto_pub -t demo/hello -m 'hi'
```

## Configuration

Set `config.conf` to a full [mosquitto.conf](https://mosquitto.org/man/mosquitto-conf-5.html);
it is rendered into a ConfigMap and mounted over the image default. Point
`config.existingConfigMap` at an externally-managed ConfigMap (key
`mosquitto.conf`) to manage it out of band; when set it wins over `config.conf`.

### Production note: default allows anonymous access

The default config enables an anonymous listener on `1883` for a zero-config
bring-up. **For production, turn this off** (`allow_anonymous false`) and add
authentication:

- A `password_file` — generate hashes with `mosquitto_passwd` (bundled in the
  image), mount the file via `extraVolumes`/`extraVolumeMounts`, and reference it
  in `config.conf`.
- A TLS listener on `8883` — mount certs and add `listener 8883` + `cafile` /
  `certfile` / `keyfile` directives.
- Fine-grained ACLs via the bundled `dynamic-security` plugin, or an `acl_file`.

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/mosquitto` | |
| `image.digest` | (CI-maintained) | signed multi-arch index |
| `replicaCount` | `1` | broker is single-instance (no OSS clustering) |
| `config.conf` | anonymous `1883` | inline mosquitto.conf (rendered + mounted) |
| `config.existingConfigMap` | `""` | external config ConfigMap (key `mosquitto.conf`, wins) |
| `persistence.enabled` | `true` | PVC at `/mosquitto/data` |
| `persistence.size` | `1Gi` | |
| `persistence.existingClaim` | `""` | reuse a pre-created PVC |
| `service.type` | `ClusterIP` | |
| `service.ports.mqtt` | `1883` | MQTT listener |

## Verify

```sh
cosign verify ghcr.io/quenchworks/images/mosquitto \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

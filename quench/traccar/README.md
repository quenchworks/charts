# Traccar

[Traccar](https://github.com/traccar/traccar) is a GPS tracking server: it speaks 200+ device protocols and gives
you live maps, geofences, reports and notifications through a React web UI and a REST API. The image is the
official 6.17.0 release on a Wolfi OpenJDK 21 JRE with 23 bundled jars swapped to fixed versions, CVE-gated,
signed with cosign and pinned by digest.

## Install

```sh
helm install traccar oci://ghcr.io/quenchworks/charts/traccar
kubectl port-forward svc/traccar 8082:8082
```

Sign in as `admin@example.com` (`admin.email`). The password is generated once and kept in the release Secret:

```sh
kubectl get secret traccar -o jsonpath='{.data.admin-password}' | base64 -d
```

## How it runs

- Traccar makes the first account that registers the admin and leaves self-registration open. A post-install Job
  creates the admin from the Secret and turns self-registration off (`allowRegistration: true` keeps it open).
- Positions, devices and users live in the bundled PostgreSQL. `/opt/traccar/data` (media) is on a PVC. One
  replica; updates stop the old pod first.
- Settings come from the environment (`CONFIG_USE_ENVIRONMENT_VARIABLES`): add any config key under `env`,
  upper-cased with dots as underscores (`geocoder.enable` is `GEOCODER_ENABLE`).
- Trackers connect from outside the cluster: list the protocols they use in `devicePorts` and expose the Service
  (`service.type: LoadBalancer` or `NodePort`). OsmAnd (5055) is the default; phones running the Traccar Client
  app use it.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.email`, `admin.password` | `admin@example.com`, generated | The admin the bootstrap Job creates. |
| `allowRegistration` | `false` | Keep Traccar's open self-registration. |
| `devicePorts` | `[{name: osmand, port: 5055}]` | Device protocol ports on the Service (`protocol: UDP` where needed). |
| `env` | `{}` | Extra config keys as environment variables. |
| `postgresql.enabled` | `true` | The bundled PostgreSQL. Off: set `externalDatabase.*` with `existingSecret`. |
| `persistence.size` | `2Gi` | `/opt/traccar/data`. |
| `service.type`, `service.port` | `ClusterIP`, `8082` | |
| `ingress.*` | off | HTTP Ingress to the web UI and API. |

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/traccar \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

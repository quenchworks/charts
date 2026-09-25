# Unleash

[Unleash](https://www.getunleash.io) is a feature-flag and gradual-rollout server:
flags, activation strategies, segments and environments, managed in an admin UI and
served to applications through the client and frontend APIs. This chart runs it on the
QuenchWorks unleash image. The image is nonroot, 0 fixable CVEs, cosign-signed and
pinned by digest. Unleash is AGPL-3.0-or-later since 8.0.

## Install

```sh
helm install unleash oci://ghcr.io/quenchworks/charts/unleash --set url=https://flags.example.com
kubectl get secret unleash -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/unleash 4242:4242
```

The chart bundles the QuenchWorks PostgreSQL chart (`postgresql.enabled`), creates the
`unleash` database, and passes its generated password to Unleash from the Secret
`<release>-postgresql`. For an existing server set `postgresql.enabled=false` and the
`externalDatabase` keys, with the password in `externalDatabase.existingSecret`.

The admin (`admin.username`, generated password) is created on the first start against
an empty database. Upstream's version check and usage telemetry are off
(`telemetry.enabled`).

## Values

| Key | Default | Meaning |
|---|---|---|
| `url` | `http://unleash.local` | public URL for links and SSO callbacks |
| `admin.username` | `admin` | first administrator |
| `admin.password` | generated | or `admin.existingSecret` (key `admin-password`) |
| `postgresql.enabled` | `true` | bundle PostgreSQL |
| `externalDatabase.*` | | host, port, database, user, existingSecret, ssl |
| `replicas` | `1` | Unleash keeps no local state and scales out |
| `telemetry.enabled` | `false` | version check and usage telemetry |

Pods run with a read-only root filesystem and all capabilities dropped. A startup probe
covers the first-start schema migration.

The release gate installs the chart with its bundled PostgreSQL on kind, signs in as the
admin, creates a flag, enables it in an environment, reads it through the client API
with a client token, recreates the Unleash pod and reads it again.

The chart depends on the `quench-common` and `postgresql` charts from
`oci://ghcr.io/quenchworks/charts`.

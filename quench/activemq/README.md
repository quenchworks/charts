# Apache ActiveMQ Classic

[ActiveMQ Classic](https://activemq.apache.org/components/classic/) is the Java message
broker: JMS over OpenWire, plus AMQP, STOMP and MQTT connectors, with KahaDB
persistence. This chart runs one broker on the QuenchWorks activemq image: the official
distribution on a Wolfi JRE, nonroot, read-only root filesystem, 0 fixable CVEs,
cosign-signed and pinned by digest.

## Install

```sh
helm install mq oci://ghcr.io/quenchworks/charts/activemq
kubectl get secret mq-activemq -o jsonpath='{.data.password}' | base64 -d
```

Clients connect to `tcp://mq-activemq:61616` as `admin` with that password.

## Auth

Upstream ships the broker open. This chart turns on `simpleAuthenticationPlugin` with one
admin user and a generated password (kept across upgrades), and gives the web console the
same user through its JAAS realm, so no default password is left. `auth.enabled: false`
restores upstream's open broker.

The web console (`:8161/admin`) accepts loopback clients only, upstream's default. Reach
it with `kubectl port-forward mq-activemq-0 8161`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.enabled` | `true` | password auth for the broker and console |
| `auth.username` / `auth.password` | `admin` / generated | the one admin user |
| `auth.existingSecret` | `""` | a Secret with the keys this chart writes |
| `connectors.amqp` / `.stomp` / `.mqtt` | `false` | extra connectors (OpenWire is always on) |
| `storeLimit` / `tempLimit` | `6 gb` / `1 gb` | KahaDB limits; keep them under `persistence.size` |
| `persistence.*` | `8Gi` PVC | KahaDB and logs under `/data` |

The chart mounts only `activemq.xml` and the auth files over the image's `conf/`; the rest
of the upstream configuration stays as shipped. It runs one broker; network-of-brokers and
shared-store failover are not wired up.

The release gate installs the chart on kind, produces persistent messages as the admin
with ActiveMQ's CLI, requires a wrong password to be refused, deletes the pod, and
consumes every message back from KahaDB.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Apache Artemis

[Apache Artemis](https://artemis.apache.org) (formerly ActiveMQ Artemis) is a
multi-protocol Java message broker: CORE, AMQP, STOMP, MQTT and OpenWire, with an
append-only journal and paging to disk. This chart runs one broker on the QuenchWorks
activemq-artemis image: the official distribution on a Wolfi JRE, nonroot, read-only root
filesystem, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install mq oci://ghcr.io/quenchworks/charts/activemq-artemis
kubectl get secret mq-activemq-artemis -o jsonpath='{.data.password}' | base64 -d
```

Clients connect to `tcp://mq-activemq-artemis:61616` as `admin` with that password. That
one acceptor speaks every protocol.

## Auth

The image requires login and ships no users. This chart writes one admin user with a
generated password (kept across upgrades) into `artemis-users.properties`, and gives it
role `amq`, which the web console needs.

The web console (`:8161/console`) accepts loopback clients only, upstream's default. Reach
it with `kubectl port-forward mq-activemq-artemis-0 8161`.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.username` / `auth.password` | `admin` / generated | the one admin user |
| `auth.existingSecret` | `""` | a Secret with `artemis-users.properties` and `artemis-roles.properties` |
| `connectors.amqp` / `.stomp` / `.mqtt` | `false` | add the protocol ports 5672, 61613, 1883 to the Service |
| `persistence.*` | `8Gi` PVC | journal, paging, large messages and logs under `/data` |

The chart mounts only the users and roles files over the image's `etc/`; the broker
configuration is the one `artemis create` wrote. It runs one broker; clustering and
replication are not wired up.

The release gate installs the chart on kind, produces messages as the admin with Artemis'
CLI, requires a wrong password to be refused, deletes the pod, and consumes every message
back from the journal.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Gravitee APIM

[Gravitee API Management](https://www.gravitee.io) (community edition) designs, secures and
publishes APIs. This chart runs its three parts on QuenchWorks images: the gateway, the
management API and the console UI, with a bundled MongoDB. All images are nonroot, run on a
read-only root filesystem, have 0 fixable CVEs, are cosign-signed and are pinned by digest.

Only the Apache-2.0 community plugins are in the images. The Enterprise plugins (Kafka,
MQTT, RabbitMQ and other message endpoints, SSE/WebSocket/webhook entrypoints, AI and MCP
proxies, and the policies that need a Gravitee license key) are removed at image build
time. HTTP and TCP proxy APIs with keyless, API key, JWT and OAuth2 plans work.

## Install

```sh
helm install apim oci://ghcr.io/quenchworks/charts/gravitee-apim
kubectl port-forward svc/apim-gravitee-apim-console 8080:8080
```

Open http://127.0.0.1:8080 and log in as `admin`. The password is generated on the first
install and kept across upgrades:

```sh
kubectl get secret apim-gravitee-apim -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

The console's nginx proxies `/management` and `/portal` to the management API, so one
address serves the UI and the API it calls. With `ingress.enabled`, `ingress.consoleHost`
routes `/`, `/management` and `/portal`, and `ingress.gatewayHost` routes to the gateway.

APIs you deploy are served by the gateway Service on port 8082.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.password` | `""` | admin password; empty generates one (key `admin-password` of the chart Secret) |
| `admin.existingSecret` | `""` | read the admin password from your own Secret (`admin.existingSecretKey`) |
| `nodeApi.password` | `""` | basic-auth password of the internal node API (user `admin`, ports 18082/18083) |
| `jwtSecret` | `""` | signs console and portal sessions; empty generates 64 characters |
| `encryptionSecret` | `""` | 32 characters, encrypts API properties; shared by gateway and API |
| `database` | `gravitee` | MongoDB database name |
| `mongodb.enabled` | `true` | bundled MongoDB; `false` plus `externalMongodb.uri` or `externalMongodb.existingSecret` |
| `gateway.replicaCount` | `1` | gateway replicas; they share state through MongoDB |
| `gateway.javaOpts`, `api.javaOpts` | `""` | extra JVM flags (`JAVA_TOOL_OPTIONS`); the heap is 70% of the memory limit |
| `gateway.extraEnv`, `api.extraEnv` | `[]` | any Gravitee setting as a `gravitee_<path>` env var |
| `console.enabled` | `true` | the admin UI |
| `ingress.*` | off | one Ingress with a console host and a gateway host |

The management API reads a gravitee.yml from this chart (ConfigMap), not the image's stock
file, which defines four demo users with published passwords. Only `admin` exists.

## Not included

- Elasticsearch: analytics and request logs are off (`repositories.analytics.type: none`)
  and the gateway's Elasticsearch reporter is disabled. Point both at your own cluster with
  `api.extraEnv` and `gateway.extraEnv` to turn them on.
- The developer portal UI. The portal REST API (`/portal`) runs in the management API.
- The SQL Server JDBC driver (the PostgreSQL and MariaDB drivers ship for a JDBC repository).

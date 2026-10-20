# Quenchworks DataHub

Hardened [DataHub](https://datahubproject.io/), the open-source metadata platform for
data discovery, lineage and governance, on minimal nonroot 0-CVE images pinned by digest
and cosign-signed. Everything runs as uid 1001 on a read-only root filesystem.

The chart deploys three images from one DataHub release:

| Part | Image | What it does |
| ---- | ----- | ------------ |
| GMS | `datahub-gms` | The metadata service: REST.li, OpenAPI and GraphQL on 8080, with the MAE, MCE and platform-event Kafka consumers embedded (no consumer Deployments). It also serves DataHub's internal schema registry, so no Confluent registry is needed. |
| Frontend | `datahub-frontend` | The React UI, login and the GraphQL proxy on 9002. This chart's main Service. |
| Setup | `datahub-upgrade` | `SystemUpdate`, a Helm hook Job: creates the SQL table, the Kafka topics and the search indices, and records the upgrade that GMS waits for. |

By default it bundles the Quenchworks MySQL, Kafka (one KRaft broker) and Elasticsearch
(single node) charts. DataHub 1.7 accepts Elasticsearch 7, 8 or 9 and OpenSearch 2.x; it
refuses OpenSearch 3, which is why the bundled search engine is Elasticsearch.

## Install

```bash
helm install datahub oci://ghcr.io/quenchworks/charts/datahub -n datahub --create-namespace --timeout 20m
```

The install returns once the setup hook has finished (it runs after the release's
resources exist and retries while MySQL, Kafka and Elasticsearch are still starting).
GMS reports healthy on `/health` a minute or two later, once it has read the upgrade
record.

Log in as `datahub` with the generated password:

```bash
kubectl get secret -n datahub datahub-datahub -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward -n datahub svc/datahub-datahub 9002:9002
# http://localhost:9002/
```

The image ships an empty `user.props`, so there is no `datahub:datahub` default login;
the chart mounts the generated credential. Set `auth.adminPassword` to choose it.

Ingestion talks to GMS inside the namespace at `http://<release>-datahub-gms:8080`
with a personal access token (UI: Settings > Access Tokens), sent as
`Authorization: Bearer <token>`.

### Why GMS readiness is a TCP check

GMS answers `/health` with 503 until `SystemUpdate` has run. The setup hook is a
`post-install` hook, and Helm (with `--wait`) and Argo CD run post-install hooks only
after the release's pods are ready, so an HTTP readiness check on `/health` would
deadlock the first install. GMS readiness and liveness therefore check the port; check
`/health` yourself when you need "fully up". On upgrades the hook runs `pre-upgrade`, so
the schema migrates before the new GMS rolls out.

A GMS that was already running while `SystemUpdate` ran stays in read-only mode
afterwards (it drops writes, so even the access tokens it mints are rejected). A second
hook therefore restarts GMS after every install and upgrade; it runs the catalog
`kubectl` image with a Role that may patch only the GMS Deployment.

## Credentials

Every empty value under `auth` is generated once into the `<release>-datahub` Secret and
kept across upgrades: `admin-password` (and the `user.props` file built from it),
`system-client-secret` (GMS and the frontend authenticate to each other with it),
`token-signing-key` and `token-salt` (access tokens) and `frontend-secret` (the session
cookie key). The bundled MySQL password stays in the MySQL chart's own Secret and is read
from there, so a first install never ends up with two different generated passwords.

## External services

| Bundled | Turn off | Then set |
| ------- | -------- | -------- |
| MySQL | `mysql.enabled=false` | `externalDatabase.host`, `.port`, `.database`, `.user` and `.password` or `.existingSecret` (MySQL 8+ or MariaDB) |
| Kafka | `kafka.enabled=false` | `externalKafka.bootstrapServers` |
| Elasticsearch | `elasticsearch.enabled=false` | `externalElasticsearch.host`, `.port`, `.useSSL` |

For a three-broker Kafka set `kafka.replicaCount=3`, the `kafka.kraft` replication
settings back to 3/2, and `topics.replicationFactor=3`. With a multi-node search cluster
set `search.replicasPerIndex=1`.

## Verify the images

```bash
for i in datahub-gms datahub-frontend datahub-upgrade; do
  cosign verify ghcr.io/quenchworks/images/$i \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  gh attestation verify oci://ghcr.io/quenchworks/images/$i --owner quenchworks
done
```

## Values

| Key | Default | Notes |
| --- | ------- | ----- |
| `images.{gms,frontend,upgrade}.repository` | `ghcr.io/quenchworks/images/datahub-*` | |
| `images.{gms,frontend,upgrade}.digest` | (CI-written) | Required. Pinned by digest, never a tag. |
| `images.pullPolicy` | `IfNotPresent` | |
| `images.kubectl.*` | `ghcr.io/quenchworks/images/kubectl` | The GMS restart hook. |
| `images.registry` | unset | Mirror prefix for all images. |
| `imagePullSecrets` | `[]` | |
| `auth.adminPassword` | generated | UI login for user `datahub`. |
| `auth.systemClientSecret` | generated | |
| `auth.tokenSigningKey` / `auth.tokenSalt` | generated | Rotating them invalidates issued tokens. |
| `auth.frontendSecret` | generated | At least 32 characters when set. |
| `gms.replicaCount` | `1` | |
| `gms.javaOpts` | `""` | `JDK_JAVA_OPTIONS`; the image sizes the heap at 75% of the limit. |
| `gms.telemetry` | `false` | DataHub's anonymous usage telemetry. |
| `gms.resources` | `500m/1536Mi`, `2/2560Mi` | |
| `gms.extraEnvVars` | `[]` | Any DataHub GMS setting. |
| `frontend.replicaCount` | `1` | |
| `frontend.javaOpts` | `""` | |
| `frontend.resources` | `250m/768Mi`, `1/1280Mi` | |
| `frontend.extraEnvVars` | `[]` | OIDC (`AUTH_OIDC_*`) and other frontend settings. |
| `setup.backoffLimit` | `10` | Attempts of the SystemUpdate Job. |
| `setup.podDeadlineSeconds` | `1200` | A stuck attempt is killed and retried. |
| `setup.javaOpts` / `setup.resources` / `setup.extraEnvVars` | | |
| `topics.partitions` / `topics.replicationFactor` | `1` / `1` | Kafka topics SystemUpdate creates. |
| `search.replicasPerIndex` | `0` | Index replicas. |
| `service.type` | `ClusterIP` | Frontend Service. |
| `service.port` | `9002` | Frontend. |
| `service.gmsPort` | `8080` | GMS Service. |
| `mysql.*` | enabled, database and user `datahub` | The Quenchworks MySQL chart. |
| `kafka.*` | enabled, one broker | The Quenchworks Kafka chart. |
| `elasticsearch.*` | enabled, single node | The Quenchworks Elasticsearch chart. |
| `networkPolicy.enabled` | `true` | Frontend and GMS ingress limited to the namespace. |
| `networkPolicy.allowExternal` | `false` | Open both to other namespaces. |
| `ingress.*` | disabled | HTTP Ingress to the frontend. |
| `serviceAccount.*`, `rbac.create` | create SA, no RBAC | |
| `podSecurityContext`, `containerSecurityContext` | `{}` | Merged over the hardened defaults. |
| scheduling knobs | | `nodeSelector`, `affinity`, `tolerations`, `topologySpreadConstraints`, `priorityClassName`, `schedulerName`, `podLabels`, `podAnnotations`. |

## Images

The three images repackage the jars from DataHub's own release images (taken by digest)
on a Wolfi JRE 25, with the vulnerable libraries replaced, including the jackson copies
bundled inside hazelcast, parquet-jackson and auth-api. DataHub ships its server
artifacts only inside its Docker images, so they are not built from source.

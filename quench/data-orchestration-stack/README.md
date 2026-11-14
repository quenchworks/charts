# Quenchworks data-orchestration-stack

Data pipelines in one install: [Dagster](https://github.com/dagster-io/dagster) 1.13.30 (webserver
and daemon) with its run and event storage in PostgreSQL, and a single-node
[Garage](https://garagehq.deuxfleurs.fr/) 2.3.0 S3 store with a bucket for your assets created at
install. All images are QuenchWorks (nonroot, CVE-gated at build, pinned by digest,
cosign-signed).

## Install

```bash
helm install data oci://ghcr.io/quenchworks/charts/data-orchestration-stack -n data --create-namespace \
  --set 'dagster.codeLocations[0].name=analytics' \
  --set 'dagster.codeLocations[0].host=analytics-code.data.svc.cluster.local' \
  --set 'dagster.codeLocations[0].port=4000'
```

## S3 for your code locations

The bucket `dagster` is created and granted to a generated key on first boot. Give a
code-location container its settings:

```yaml
envFrom:
  - configMapRef: { name: data-s3 }     # AWS_ENDPOINT_URL, AWS_REGION (garage), DAGSTER_S3_BUCKET
env:
  - name: AWS_ACCESS_KEY_ID
    valueFrom: { secretKeyRef: { name: data-garage, key: access-key } }
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom: { secretKeyRef: { name: data-garage, key: secret-key } }
```

Then an IO manager from `dagster-aws` (in your code-location image) writes assets there, for
example `S3PickleIOManager` with `s3_bucket` from `DAGSTER_S3_BUCKET`. The webserver and daemon
carry the same variables.

## Values

| Key | Default | Notes |
|---|---|---|
| `dagster.*` | | passes to the [dagster chart](../dagster): `codeLocations`, `example`, `postgresql`, `runCoordinator` |
| `garage.config.defaultBucket` | `dagster` | created on first boot |
| `garage.*` | | passes to the [garage chart](../garage): `persistence`, `config.capacity` |

## Notes

- One stack per namespace: Garage has the fixed name `data-garage` (`garage.fullnameOverride`),
  so its Secret and Service can be named from plain values.
- The QuenchWorks dagster image does not include `dagster-aws`, so compute logs stay on the
  default local manager; your code-location images bring `dagster-aws` for S3 IO managers.
- Garage here is a single node. For a replicated store, run the garage chart on its own and
  point `data-s3` style settings at it.

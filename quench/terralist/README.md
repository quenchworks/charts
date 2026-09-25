# Terralist

[Terralist](https://www.terralist.io) is a private Terraform and OpenTofu registry for
modules and providers. It speaks the registry protocol, has a web UI, logs people in
through GitHub, GitLab, Bitbucket or OIDC, and issues API keys for CI. This chart runs it
on the QuenchWorks terralist image. The image is nonroot, 0 fixable CVEs, cosign-signed
and pinned by digest.

## Install

Terralist refuses to start without an OAuth app. Create one with the callback URL
`<url>/v1/api/auth/redirect`, then:

```sh
kubectl create secret generic terralist-oauth --from-literal=client-id=... --from-literal=client-secret=...
helm install terralist oci://ghcr.io/quenchworks/charts/terralist \
  --set url=https://registry.example.com --set oauth.existingSecret=terralist-oauth
terraform login registry.example.com
```

The chart generates the token-signing, cookie and OAuth-state secrets once and keeps
them across upgrades. Every setting reaches Terralist as a `TERRALIST_*` environment
variable, so anything the chart does not model (OIDC endpoints, S3 settings, RBAC) goes
in `extraEnvVars`, for example `TERRALIST_OI_AUTHORIZE_URL`.

## Storage and database

Uploaded module and provider archives go to the PVC with `storage.resolver: local`, or
to S3, GCS or Azure (`s3`, `gcs`, `azure` plus their `TERRALIST_*` settings), or stay
upstream with `proxy`. The database is SQLite on the same PVC, or PostgreSQL or MySQL
from `database.existingSecret` (a connection URL). One replica; the pod is recreated on
upgrade because SQLite and the local store sit on one ReadWriteOnce volume.

## Values

| Key | Default | Meaning |
|---|---|---|
| `url` | `http://terralist.local` | public URL of the registry |
| `oauth.provider` | `github` | `github`, `gitlab`, `bitbucket` or `oidc` |
| `oauth.existingSecret` | `""` | Secret with `client-id` and `client-secret` |
| `masterApiKey.enabled` | `false` | a generated full-access key for bootstrapping |
| `storage.resolver` | `local` | `local`, `proxy`, `s3`, `gcs` or `azure` |
| `database.type` | `sqlite` | `sqlite`, `postgresql` or `mysql` |
| `persistence.size` | `5Gi` | SQLite and the local store |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind, creates an authority with the master key,
uploads a module version, lists it and downloads its archive through the registry
protocol, recreates the pod, and requires the module to still be served.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

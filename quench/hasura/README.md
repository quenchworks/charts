# Quenchworks Hasura GraphQL Engine

[Hasura GraphQL Engine](https://hasura.io/) Community Edition: an instant GraphQL
API with role-based permissions over PostgreSQL. The image runs nonroot (uid
`1001`), is pinned by digest and cosign-signed, and serves GraphQL, the metadata
API and the console on port `8080`.

The server is upstream's Apache-2.0 Community Edition build, taken by digest from
its `-ce` images. Telemetry is off. The chart bundles the Quenchworks PostgreSQL
chart for Hasura's metadata; point it at your own databases from the console or
the metadata API.

## Install

```bash
helm install gql oci://ghcr.io/quenchworks/charts/hasura
kubectl get secret gql-hasura -o jsonpath='{.data.admin-secret}' | base64 -d; echo
kubectl port-forward svc/gql-hasura 8080:8080   # console: http://localhost:8080/console
```

## Values

| Key | Default | Notes |
|---|---|---|
| `adminSecret` | `""` | Generated when empty, kept across upgrades |
| `console` | `true` | Serve `/console` |
| `unauthorizedRole` | `""` | Role for anonymous requests; empty refuses them |
| `replicaCount` | `1` | Stateless, scales horizontally |
| `postgresql.enabled` | `true` | Bundled metadata database |
| `externalDatabase.*` | | Host, credentials, `sslMode`, or `existingSecret` with a full URL |
| `networkPolicy.allowExternal` | `false` | Ingress only from the release namespace |

JWT or webhook authentication goes in `extraEnvVars`, for example
`HASURA_GRAPHQL_JWT_SECRET` from a Secret.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/hasura \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

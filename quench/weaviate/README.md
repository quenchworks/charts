# Quenchworks Weaviate

Hardened [Weaviate](https://github.com/weaviate/weaviate) vector database on a
minimal, nonroot, 0-CVE image, built from source and pinned by digest. Runs as a
StatefulSet with a per-replica PVC; serves the REST API and gRPC.

## Install

```sh
helm install vectors oci://ghcr.io/quenchworks/charts/weaviate
```

The server runs nonroot and serves REST on container port 8080 and gRPC on 50051;
the Service exposes both. Check readiness over a port-forward:

```sh
kubectl port-forward svc/vectors-weaviate 8080:8080
curl http://127.0.0.1:8080/v1/.well-known/ready
curl http://127.0.0.1:8080/v1/schema
```

## Configuration

Weaviate is configured entirely through environment variables. The `env` map is
rendered verbatim into the container; the defaults bring up a single anonymous
node with no vectorizer module. Add or override keys to enable modules, set
authentication, etc. Keep `env.PERSISTENCE_DATA_PATH` aligned with
`persistence.path` (both default to `/var/lib/weaviate`).

```yaml
env:
  AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: "true"
  PERSISTENCE_DATA_PATH: /var/lib/weaviate
  CLUSTER_HOSTNAME: node1
  QUERY_DEFAULTS_LIMIT: "25"
  DEFAULT_VECTORIZER_MODULE: none
  ENABLE_MODULES: ""
```

## Values

| Key                           | Default                               | Notes                                                                                     |
| ----------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- | --------- |
| `image.repository`            | `ghcr.io/quenchworks/images/weaviate` |                                                                                           |
| `image.digest`                | (CI-written)                          | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                   | Single node for now.                                                                      |
| `persistence.enabled`         | `true`                                | PVC mounted at `persistence.path`.                                                        |
| `persistence.size`            | `8Gi`                                 | Provisioned per replica via `volumeClaimTemplates`.                                       |
| `persistence.path`            | `/var/lib/weaviate`                   | Mount path; mirror into `env.PERSISTENCE_DATA_PATH`.                                      |
| `persistence.existingClaim`   | `""`                                  | Bind an existing PVC instead of provisioning one.                                         |
| `env`                         | (see above)                           | Map of `WEAVIATE/*_*` env vars, rendered into the container.                              |
| `service.type`                | `ClusterIP`                           |                                                                                           |
| `service.httpPort`            | `8080`                                | REST API.                                                                                 |
| `service.grpcPort`            | `50051`                               | gRPC API.                                                                                 |
| `autoscaling.enabled`         | `false`                               | Single-node default; HPA targets the StatefulSet.                                         |
| `serviceAccount.create`       | `true`                                | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                               | Minimal Role/RoleBinding when enabled.                                                    |
| `networkPolicy.enabled`       | `true`                                | Ingress on http + grpc; external allowed by default.                                      |
| `podDisruptionBudget.enabled` | `true`                                | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                               | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                  | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                  | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                                | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                  | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                  | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

## Health

- Liveness: `GET /v1/.well-known/live` on the REST port.
- Readiness: `GET /v1/.well-known/ready` on the REST port.

## Security

Runs nonroot on a read-only root filesystem with all capabilities dropped. Only
the data volume (`persistence.path`) is writable.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/weaviate \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/weaviate \
  --owner quenchworks
```

## Notes

Single node for now. A clustered (sharded/replicated) topology over the headless
service is tracked as a follow-up.

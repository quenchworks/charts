# Quenchworks ExternalDNS

Hardened [ExternalDNS](https://github.com/kubernetes-sigs/external-dns), the
Kubernetes SIG controller that keeps an external DNS provider in sync with the
Services, Ingresses and Gateway API routes exposed in your cluster, on a minimal,
nonroot, 0-CVE image built from source, cosign-signed and pinned by digest.

The chart's **default provider is `inmemory`** — a real ExternalDNS provider that
holds the zone inside the process. It needs no cloud credentials, so
`helm install` works on any cluster and the controller genuinely reconciles; it
just has nowhere durable to put the records. Point `provider` at your real DNS
provider before relying on it.

## Install

```bash
helm install dns oci://ghcr.io/quenchworks/charts/external-dns
```

With a real provider (AWS Route 53, IRSA-authenticated):

```bash
helm install dns oci://ghcr.io/quenchworks/charts/external-dns \
  --set provider=aws \
  --set policy=sync \
  --set txtOwnerId=prod-cluster \
  --set 'domainFilters={example.com}' \
  --set 'serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::123456789012:role/external-dns'
```

Credentials for providers that take them as environment variables go through the
shared `extraEnvVars` / `extraEnvVarsSecret` knobs — never inline in values:

```yaml
provider: cloudflare
extraEnvVarsSecret: cloudflare-api-token   # supplies CF_API_TOKEN
```

Publish a hostname by annotating a Service or Ingress:

```bash
kubectl annotate svc my-app external-dns.alpha.kubernetes.io/hostname=app.example.com
```

## Verify it is actually working

A controller with missing RBAC stays `Ready` forever while doing nothing, so
check the log rather than the pod status:

```bash
kubectl logs deployment/dns-external-dns | grep -iE 'forbidden|cannot list'   # must be empty
kubectl logs deployment/dns-external-dns | grep -E 'CREATE|UPDATE|DELETE'     # records it applied
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/external-dns \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/external-dns --owner quenchworks`.

## Values

| Key                                    | Default                                   | Notes                                                                                                       |
| -------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `image.repository`                     | `ghcr.io/quenchworks/images/external-dns` |                                                                                                             |
| `image.digest`                         | (CI-written)                              | Required. Charts pin by digest, never a tag.                                                                |
| `image.pullPolicy`                     | `IfNotPresent`                            |                                                                                                             |
| `nameOverride`                         | `""`                                      | Override the chart name in resource names.                                                                  |
| `replicaCount`                         | `1`                                       | Must stay `1`: ExternalDNS has no leader election, so two replicas both write to the provider.              |
| `updateStrategy`                       | `{type: Recreate}`                        | Same reason — never two instances at once, not even during a rollout.                                       |
| `provider`                             | `inmemory`                                | The DNS provider. `aws`, `google`, `azure`, `cloudflare`, `rfc2136`, `pdns`, … see `external-dns --help`.   |
| `inmemoryZones`                        | `[]`                                      | Zones the `inmemory` provider serves. Ignored by every other provider.                                      |
| `sources`                              | `[service, ingress]`                      | Also `node`, `crd`, `gateway-httproute`, `gateway-grpcroute`, …                                             |
| `domainFilters`                        | `[]`                                      | Zones ExternalDNS may touch. Empty means every zone the credentials can reach — set this in production.     |
| `policy`                               | `upsert-only`                             | `upsert-only` never deletes. `sync` gives ExternalDNS full ownership of the zone, deletions included.        |
| `registry`                             | `txt`                                     | Ownership registry. `txt` writes a companion TXT record; `noop` tracks no ownership.                        |
| `txtOwnerId`                           | `default`                                 | Identifies this instance in the TXT records. Must differ per cluster sharing a zone.                        |
| `txtPrefix`                            | `""`                                      | Prefix for the ownership TXT record name.                                                                   |
| `interval`                             | `1m`                                      | Reconcile interval.                                                                                         |
| `triggerLoopOnEvent`                   | `true`                                    | Also reconcile on source-object events (`--events`), not only on the interval.                              |
| `dryRun`                               | `false`                                   | Log the changes instead of applying them.                                                                   |
| `logLevel` / `logFormat`               | `info` / `text`                           | `logFormat: json` for structured logs.                                                                      |
| `extraArgs`                            | `[]`                                      | Extra flags, e.g. `--publish-internal-services`, `--namespace=team-a`.                                      |
| `resources.requests`                   | `cpu 25m / mem 64Mi`                      |                                                                                                             |
| `resources.limits`                     | `cpu 250m / mem 256Mi`                    |                                                                                                             |
| `service.type`                         | `ClusterIP`                               |                                                                                                             |
| `service.port`                         | `7979`                                    | Metrics and `/healthz` only — nothing is routed through this controller.                                    |
| `serviceAccount.create`                | `true`                                    |                                                                                                             |
| `serviceAccount.automountServiceAccountToken` | `true`                             | Required: ExternalDNS is an API-server client.                                                              |
| `serviceAccount.annotations`           | `{}`                                      | Where cloud workload-identity annotations (IRSA, GKE WI) go.                                                |
| `rbac.create`                          | `true`                                    | Cluster-wide read on the source objects; the only write is `dnsendpoints/status`.                           |
| `networkPolicy.enabled`                | `true`                                    | Restricts ingress to the metrics port.                                                                      |
| `networkPolicy.allowExternal`          | `false`                                   | Set `true` (or use `extraFrom`) to let a Prometheus in another namespace scrape it.                          |
| `podDisruptionBudget.enabled`          | `false`                                   | A single-replica singleton cannot satisfy a PDB — it would block node drains, not protect availability.     |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts).

## Architecture

A single-replica Deployment runs `/usr/bin/external-dns` with the flags composed
from values. Every reconcile it lists the configured `sources`, turns their
hostname annotations and load-balancer addresses into DNS endpoints, filters them
by `domainFilters`, reconciles them against the provider under `policy`, and
records ownership through `registry`. It serves `/healthz` and `/metrics` on
container port `7979` — both probes use `/healthz` — and the Service exposes the
same port for scraping.

RBAC is cluster-scoped because a Service, an Ingress or an HTTPRoute may live in
any namespace. It is read-only apart from `dnsendpoints/status` and event
creation: ExternalDNS writes to DNS, not to the cluster. The rules cover every
source the chart can enable, which is harmless for the ones you do not — RBAC is
granted on group/resource strings, and no informer starts for a source that is
not in `sources`. The ClusterRole and ClusterRoleBinding names carry the release
namespace so two releases never collide on a cluster-scoped object.

The container runs nonroot on a read-only root filesystem with all capabilities
dropped, and mounts nothing.

## Uninstall

```bash
helm uninstall dns
```

With `policy: upsert-only` (the default) the records ExternalDNS created stay in
your zone after uninstall, along with their ownership TXT records — remove them
by hand, or run one last reconcile under `policy: sync` with the sources deleted.

## Notes

The chart depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`. Two warnings worth repeating:
`policy: sync` lets ExternalDNS **delete** records in the zones it matches, so
pair it with a `domainFilters` you are sure of; and `txtOwnerId` must be unique
per cluster, or two ExternalDNS instances will each decide the other's records
are stale.

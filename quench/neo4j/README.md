# Quenchworks Neo4j (Community Edition)

Hardened [Neo4j](https://neo4j.com/) **Community Edition** on a minimal, nonroot,
0-CVE image pinned by digest. The upstream Community binary distribution runs on a
hardened Wolfi JRE. The HTTP API and Neo4j Browser are served on port `7474`; the
Bolt protocol (drivers, `cypher-shell`) on `7687`. Single node.

> **License: GPLv3.** This is Neo4j **Community Edition** only. Enterprise features
> (causal clustering, role-based access control, online backup) are NOT included.
> The Graph Data Science / GenAI products and the APOC plugin are intentionally
> dropped from the image to keep it Community-GPLv3-clean. Causal clustering is an
> Enterprise-only feature, so this chart is single node (a follow-up could add it
> only against an Enterprise image).

## Install

```bash
helm install graph oci://ghcr.io/quenchworks/charts/neo4j
```

Neo4j refuses the default `neo4j/neo4j` credentials, so authentication is required.
The chart stores the full `neo4j/<password>` string in a Secret (a random 24-char
password is generated if you do not supply one) and maps it into `NEO4J_AUTH`. On
the first ever boot the entrypoint runs `neo4j-admin dbms set-initial-password`
(guarded by a marker in `/data`); restarts and upgrades preserve the existing
password.

## Connect

```bash
# password
PW="$(kubectl get secret graph-neo4j -o jsonpath='{.data.neo4j-password}' | base64 -d)"

# Cypher write + read roundtrip with the bundled cypher-shell
kubectl exec graph-neo4j-0 -- cypher-shell -u neo4j -p "$PW" \
  "CREATE (:Thing {name:'quench'}) RETURN 1"
kubectl exec graph-neo4j-0 -- cypher-shell -u neo4j -p "$PW" \
  "MATCH (t:Thing) RETURN t.name"

# HTTP discovery JSON (unauthenticated)
curl -fsS http://graph-neo4j:7474/

# Bolt driver target
# bolt://graph-neo4j.<namespace>.svc.cluster.local:7687
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/neo4j \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/neo4j --owner quenchworks`.

## Values

| Key                           | Default                            | Notes                                                                                     |
| ----------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/neo4j` |                                                                                           |
| `image.digest`                | (CI-written)                       | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                | Single node (Community Edition).                                                          |
| `auth.enabled`                | `true`                             | `false` disables auth (`NEO4J_AUTH=none`) — not for production.                           |
| `auth.username`               | `neo4j`                            | Community fixes the admin user to `neo4j`.                                                |
| `auth.password`               | (generated)                        | 24-char random if empty; stored in the Secret.                                            |
| `auth.existingSecret`         | `""`                               | Use an existing Secret holding the `neo4j/<pw>` string.                                   |
| `auth.existingSecretAuthKey`  | `neo4j-auth`                       | Key in `existingSecret` for `NEO4J_AUTH`.                                                 |
| `heap.initial` / `heap.max`   | `512m`                             | JVM heap (`server.memory.heap.*`).                                                        |
| `heap.pagecache`              | `256m`                             | Page cache (`server.memory.pagecache.size`).                                              |
| `extraConfig`                 | `{}`                               | Extra `neo4j.conf` settings (`NEO4J_<setting>` env mapping).                              |
| `persistence.enabled`         | `true`                             | 8Gi PVC at `/data`.                                                                       |
| `service.httpPort`            | `7474`                             | HTTP API + Browser.                                                                       |
| `service.boltPort`            | `7687`                             | Bolt protocol.                                                                            |
| `networkPolicy.enabled`       | `true`                             | Restricts ingress (7474 + 7687) to the namespace.                                         |
| `podDisruptionBudget.enabled` | `true`                             | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                            | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                               | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                               | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                             | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                               | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                               | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The graph store and transaction logs live on the writable `/data` volume;
`/logs`, `/conf` (seeded from the dist on first boot), and `/var/run/neo4j` are
emptyDir. Credentials live in a Kubernetes Secret. Keep Neo4j behind the
NetworkPolicy for internal use.

> **`/data` must allow exec.** JNA unpacks `libjnidispatch.so` under the JVM tmpdir
> (routed to `/data/tmp`) and maps it executable; a `noexec` data volume crashes boot
> with "failed to map segment". Kubernetes PVC/emptyDir volumes are exec by default.
> If a `noexec` PVC is ever forced, point `NEO4J_TMP_DIR` at a separate exec emptyDir
> via `extraEnvVars`/`extraVolumes`.

## Notes

Single node (Community Edition; causal clustering is Enterprise-only). First-run
auth setup is idempotent — it runs only on the first boot, so restarts and upgrades
preserve the existing password. Depends on the `quench-common` library chart, pulled
from `oci://ghcr.io/quenchworks/charts/quench-common`.

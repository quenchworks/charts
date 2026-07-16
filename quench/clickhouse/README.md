# Quenchworks ClickHouse

Hardened [ClickHouse](https://clickhouse.com/) on a minimal, nonroot, 0-CVE image
pinned by digest. Ships ClickHouse's own official self-contained static binary
(the multi-call `clickhouse`: server/client/keeper/local), hardened on Wolfi and
gated 0-CVE with Trivy. The HTTP API is served on port `8123` and the native TCP
protocol on `9000`. Single node.

## Install

```bash
helm install ch oci://ghcr.io/quenchworks/charts/clickhouse
```

On first boot the entrypoint seeds a writable config dir from the upstream defaults
and writes a `users.d/` drop-in for the configured user. The password is stored as
a sha256 hash (never plaintext) and lives in a Kubernetes Secret (generated if you
do not supply one).

## Connect

```bash
PASSWORD="$(kubectl get secret ch-clickhouse -o jsonpath='{.data.admin-password}' | base64 -d)"
HOST=http://ch-clickhouse:8123

curl -fsS "$HOST/ping"                                  # -> Ok.
curl -fsS "$HOST/?user=default&password=$PASSWORD" --data-binary 'SELECT version()'

curl -fsS "$HOST/?user=default&password=$PASSWORD" \
  --data-binary 'CREATE TABLE IF NOT EXISTS demo (id UInt32, name String) ENGINE = MergeTree ORDER BY id'
curl -fsS "$HOST/?user=default&password=$PASSWORD" --data-binary "INSERT INTO demo VALUES (1, 'quench')"
curl -fsS "$HOST/?user=default&password=$PASSWORD" --data-binary 'SELECT name FROM demo WHERE id = 1'
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/clickhouse \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/clickhouse \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/clickhouse` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Single node. |
| `auth.username` | `default` | First-run user. |
| `auth.password` | (generated) | 24-char random if empty; stored (sha256) in the Secret. |
| `auth.database` | `""` | Optional initial database created on first boot. |
| `auth.defaultAccessManagement` | `true` | Enable SQL-driven access management for the user. |
| `auth.existingSecret` | `""` | Use an existing Secret for the password. |
| `persistence.enabled` | `true` | 8Gi PVC at `/var/lib/clickhouse`. |
| `service.httpPort` | `8123` | HTTP API (primary client/service port). |
| `service.nativePort` | `9000` | Native TCP protocol. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. The data lives on the writable `/var/lib/clickhouse` volume; the config
dir `/etc/clickhouse-server` (regenerated from env each boot), the logs at
`/var/log/clickhouse-server`, and `/tmp` are emptyDir. The password lives in a
Kubernetes Secret. Keep ClickHouse behind the NetworkPolicy for internal use.

## Notes

Single node. Clustering uses ClickHouse Keeper / ZooKeeper and is a follow-up (not
implemented in this chart). The config dir is regenerated from env on every boot,
so credential and bind changes apply on restart; the data dir persists. Depends on
the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.

# Quenchworks Pgpool-II

Hardened [Pgpool-II](https://www.pgpool.net/) — a connection pooler, load balancer and
query router for PostgreSQL — on a minimal, nonroot, 0-CVE image pinned by digest.
Pgpool-II sits between your applications and a PostgreSQL cluster: it pools connections,
routes read-only queries across streaming-replication standbys, keeps writes on the
primary, and detaches a node that stops answering health checks. The client listener is
port `9999`; the PCP admin protocol is `9898`.

Built from the official pgpool.net source tarball on Wolfi (OpenSSL + libpq from
PostgreSQL 18, no PAM/LDAP). The runtime runs as uid 1001 on a read-only root filesystem;
its unix sockets + pidfile live in an emptyDir at `/var/run/pgpool`, `pgpool_status` and
lock files in an emptyDir at `/tmp`, logs go to stderr.

This chart bundles the Quenchworks PostgreSQL chart by default (for a self-contained
demo/gate) and is designed to front an **existing** PostgreSQL cluster in production.

## Install

```bash
# self-contained: bundles in-cluster PostgreSQL with deterministic shared creds
helm install pool oci://ghcr.io/quenchworks/charts/pgpool
```

## Connect

Point your applications at the pooler instead of PostgreSQL directly:

```
host : pool-pgpool
port : 9999
user : appuser
db   : appdb
```

```bash
# bundled PG password
PW=$(kubectl get secret pool-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

# verify pooling end-to-end (psql ships in the Quenchworks postgresql image)
kubectl run pgclient --rm -it --restart=Never \
  --image=ghcr.io/quenchworks/images/postgresql:18.4 -- \
  psql "host=pool-pgpool port=9999 user=appuser dbname=appdb password=$PW" -c 'SELECT 1;'
```

### Pgpool-II's own SHOW commands

Answered by the pooler itself on the same connection — the quickest way to confirm you are
really talking to Pgpool-II and to see where queries went:

```bash
psql "host=pool-pgpool port=9999 user=appuser dbname=appdb password=$PW" \
  -c 'SHOW POOL_NODES;'      # one row per backend: role, status, weight, select_cnt, delay
# also: SHOW POOL_PROCESSES; SHOW POOL_POOLS; SHOW POOL_CACHE; SHOW POOL_VERSION;
```

### PCP admin protocol

`pcp_node_count`, `pcp_node_info`, `pcp_detach_node`, `pcp_attach_node` and
`pcp_recovery_node` speak PCP on port `9898`. No users are configured by default, so the
listener accepts nothing — add one:

```yaml
pcp:
  users:
    # the MD5 HASH, not the plaintext: pg_md5 <password>  (or printf %s pw | md5sum)
    admin: 71a4a17a658b90a7f847585721b5a217
```

PCP clients read the password from a file named by `$PCPPASSFILE`, one
`host:port:user:password` line, mode `0600`.

## Backend nodes

### External (production)

The real use case: front an existing cluster. Node `0` is the primary; the rest are
standbys that receive load-balanced read-only traffic.

```yaml
postgresql:
  enabled: false
backends:
  - host: pg-primary.db.svc.cluster.local
    port: 5432
    weight: 1
    flag: ALLOW_TO_FAILOVER
  - host: pg-replica-0.db.svc.cluster.local
    weight: 1
  - host: pg-replica-1.db.svc.cluster.local
    weight: 1
auth:
  database: appdb
  username: appuser
  password: ""               # or supply existingSecret (then also set poolPasswd.existingSecret)
```

The credentials must be valid on **every** backend: Pgpool-II authenticates clients with
them and reuses them for the health check and the primary-node check.

### Bundled (demo / CI)

`postgresql.enabled=true` deploys the Quenchworks PostgreSQL subchart as the single node.
Pgpool-II and PG share deterministic credentials under `postgresql.auth`, so `pool_passwd`
and the backend list are derived automatically:

```yaml
postgresql:
  enabled: true
  auth:
    username: appuser        # MUST differ from `database` (image init quirk)
    password: appsecret      # set a real password in production
    database: appdb
```

## Clustering modes

`pgpool.clusteringMode` selects what Pgpool-II does beyond pooling:

| Mode | Behavior | Use when |
|------|----------|----------|
| `streaming_replication` (default) | Read/write split against a primary + physical standbys; re-detects the primary via `sr_check`. | Standard PostgreSQL HA. |
| `raw` | Pass-through to node 0; no load balancing, no replication awareness. | A single PostgreSQL server. |
| `native_replication` / `snapshot_isolation` | Pgpool-II writes to every node itself. | Legacy multi-master setups. |
| `logical_replication` / `slony` | Replication handled outside Pgpool-II. | Those tools are already in place. |

Total backend connections ≈ `replicaCount × num_init_children × max_pool`. Size
`num_init_children` against your PostgreSQL `max_connections`.

## Authentication

`pgpool.authMethod` is the method written into `pool_hba.conf` for TCP clients
(`scram-sha-256` by default, matching the Quenchworks PostgreSQL image). The chart writes a
`pool_passwd` Secret with `username:password` lines — an unprefixed value is treated as
plaintext, which is exactly what SCRAM needs: Pgpool-II uses it to verify the client **and**
to log in to the backends. The `health_check_password` and `sr_check_password` settings are
deliberately left empty so Pgpool-II resolves them from `pool_passwd` too, keeping every
credential out of the ConfigMap. Add extra users via `poolPasswd.extraUsers`, or supply a
fully managed file with `poolPasswd.existingSecret`.

Unix-socket and loopback connections are `trust`ed so in-pod tooling works.

## Failover

No `failover_command` is configured: the runtime image has no shell, so promoting a standby
is left to Kubernetes / your PostgreSQL operator. Pgpool-II still does the pooler half of
the job — it detaches a node that fails `health_check` and re-detects the primary via
`sr_check`, so traffic follows the new primary once it is promoted. `pgpool_status` lives on
an emptyDir, so node up/down state is rebuilt from health checks after a restart.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/pgpool \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/pgpool --owner quenchworks`.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/pgpool` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless pooler; raise to scale (watch total backend connections). |
| `postgresql.enabled` | `true` | Bundle the Quenchworks PostgreSQL subchart (demo/CI). |
| `postgresql.auth.{username,password,database}` | `appuser`/`appsecret`/`appdb` | Deterministic shared creds; user ≠ database. |
| `backends` | `[]` | Backend nodes when `postgresql.enabled=false`; node 0 is the primary. |
| `auth.*` | `""` | Credentials for external backends (inline or `existingSecret`). |
| `pgpool.clusteringMode` | `streaming_replication` | See the table above. |
| `pgpool.authMethod` | `scram-sha-256` | Client auth in `pool_hba.conf`. |
| `pgpool.numInitChildren` | `32` | Pre-forked children = max concurrent clients. |
| `pgpool.maxPool` | `4` | Cached connections per child, per (user, database). |
| `pgpool.connectionCache` | `true` | The connection pooling itself. |
| `pgpool.loadBalanceMode` | `true` | Spread read-only queries over the standbys. |
| `pgpool.healthCheckPeriod` | `10` | Seconds; `0` disables health checks (and failover). |
| `pgpool.srCheckPeriod` | `10` | Seconds; primary detection + replication delay. |
| `pgpool.delayThreshold` | `10000000` | WAL lag (bytes) before a standby stops taking reads. |
| `pgpool.extraConfig` | `""` | Raw `key = value` lines appended to `pgpool.conf`. |
| `pgpool.raw` | `""` | Full `pgpool.conf` to bypass templating (advanced). |
| `poolPasswd.existingSecret` | `""` | Provide your own `pool_passwd` Secret. |
| `poolPasswd.extraUsers` | `{}` | Extra `{user: password}` entries appended to the list. |
| `pcp.users` | `{}` | `{user: md5-of-password}` for the PCP admin protocol. |
| `service.port` | `9999` | Client listener. |
| `service.pcpPort` | `9898` | PCP admin listener. |
| `networkPolicy.enabled` | `true` | Ingress 9999/9898 (in-namespace), egress to backends + DNS. |
| `networkPolicy.allowExternal` | `false` | Set true to accept connections from outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities dropped. The
only writable paths are emptyDir mounts at `/var/run/pgpool` (sockets + pidfile) and `/tmp`
(`pgpool_status`, lock files). `pgpool.conf` and `pool_hba.conf` come from a ConfigMap;
`pool_passwd` and `pcp.conf` from Secrets — all mounted read-only as individual files under
`/etc/pgpool`. A tcpSocket probe on 9999 gates readiness and liveness, deliberately: the
pooler must stay up while a backend is down, which is exactly when it detaches nodes and
re-detects the primary. The release install gate does the deeper check (`SELECT 1` and
`SHOW POOL_NODES` through the pooler).

## Uninstall

```bash
helm uninstall pool
```

The pooler itself is stateless and holds no PVCs. When the bundled PostgreSQL
subchart is enabled, its PVC is retained by Kubernetes on uninstall — delete it
explicitly if you want the data gone:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=pool
```

## Notes

Depends on the `quench-common` library chart and the Quenchworks `postgresql` chart, both
pulled from `oci://ghcr.io/quenchworks/charts`. The chart supplies the real configuration
(the image ships only bootable defaults) at the entrypoint's paths — the image runs
`pgpool -n -f /etc/pgpool/pgpool.conf -F /etc/pgpool/pcp.conf -a /etc/pgpool/pool_hba.conf`
directly, with no shell in the image.

`logdir` (≤ 4.6) was renamed `work_dir` (≥ 4.7) upstream, and an unknown parameter is a
startup FATAL, so the chart sets neither and relies on Pgpool-II's default of `/tmp` —
which keeps the rendered config valid across every image tag the factory publishes.

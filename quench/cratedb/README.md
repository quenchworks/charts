# CrateDB

[CrateDB](https://cratedb.com) is a distributed SQL database built on Lucene for time
series, logs, geospatial and full-text search. Clients talk to it over the PostgreSQL wire
protocol or an HTTP SQL endpoint. This chart runs it on the QuenchWorks cratedb image: the
official distribution on a Wolfi Java 25 runtime, nonroot, read-only root filesystem,
0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install crate oci://ghcr.io/quenchworks/charts/cratedb
```

CrateDB's host-based auth trusts the `crate` superuser from local connections only, and a
`kubectl port-forward` counts as local. Create an application user through one, then
connect over the PostgreSQL protocol with it:

```sh
kubectl port-forward crate-cratedb-0 4200 &
curl -s -H 'Content-Type: application/json' localhost:4200/_sql \
  -d "{\"stmt\":\"CREATE USER app WITH (password = 'change-me')\"}"
curl -s -H 'Content-Type: application/json' localhost:4200/_sql -d '{"stmt":"GRANT ALL TO app"}'
psql -h crate-cratedb -p 5432 -U app doc
```

## Nodes

`replicas: 1` runs a single node (`discovery.type=single-node`, which also skips the
production bootstrap checks). More replicas form a cluster over the headless Service with
the pods as initial master nodes. A cluster enforces the bootstrap checks, so every
Kubernetes node that runs CrateDB needs `vm.max_map_count >= 262144`; this chart does not
set that sysctl, because it would need a privileged container.

## Values

| Key | Default | Meaning |
|---|---|---|
| `replicas` | `1` | nodes; > 1 forms a cluster |
| `extraArgs` | `[]` | extra `-C<setting>=<value>` flags |
| `extraEnv` | `[]` | e.g. `JDK_JAVA_OPTIONS` to override the heap (default 50% of the limit) |
| `persistence.*` | `16Gi` PVC per node | data under `/data` |
| `service.httpPort` / `service.pgPort` | `4200` / `5432` | HTTP SQL and PostgreSQL protocol |

Probes are TCP: an HTTP probe from the kubelet is not a local connection and would be
asked for a password.

The release gate installs one node on kind, creates a password user through a
port-forward, writes a table, reads it back over the PostgreSQL protocol with `psql` from
another pod (and requires a wrong password to be refused), deletes the pod, and requires
the rows back.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

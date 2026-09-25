# Gogs

[Gogs](https://gogs.io) is a painless self-hosted Git service: repositories, issues, pull
requests, wikis and webhooks, over HTTP and its own built-in SSH server. This chart runs
it on the QuenchWorks gogs image. The image is nonroot, 0 fixable CVEs, cosign-signed and
pinned by digest.

## Install

```sh
helm install gogs oci://ghcr.io/quenchworks/charts/gogs \
  --set externalURL=https://git.example.com/ --set sshDomain=git.example.com
kubectl get secret gogs -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/gogs 3000:3000
```

The chart locks the install page. It renders `app.ini` into a ConfigMap, generates a
secret key (kept across upgrades), and creates the admin from `admin` once the database
is ready. Self-registration is off (`registration.enabled`).

## Database

SQLite on the data volume by default. For PostgreSQL or MySQL set `database.type`,
`database.host` (`host:port`), `database.name`, `database.user` and
`database.existingSecret` with the password. Secrets reach `app.ini` as environment
variables, which Gogs expands in every value, so a literal `$` in `extraConfig` must be
written `$$`.

## SSH

The built-in SSH server listens on 2222 in the pod and on `ssh.port` (22) on the Service.
Clone URLs show `git@<sshDomain>`. Expose the Service's `ssh` port (a LoadBalancer or a
TCP route) to reach it from outside.

## Values

| Key | Default | Meaning |
|---|---|---|
| `externalURL` | `http://gogs.local/` | public URL for links and clone URLs |
| `sshDomain` | `gogs.local` | host in SSH clone URLs |
| `admin.username` / `admin.email` | `gogs-admin` | first administrator |
| `admin.password` | generated | or `admin.existingSecret` (key `admin-password`) |
| `database.type` | `sqlite3` | `sqlite3`, `postgres` or `mysql` |
| `ssh.enabled` | `true` | built-in SSH server |
| `persistence.size` | `10Gi` | repositories, SQLite, attachments |
| `extraConfig` | `""` | more `app.ini`, appended |

One replica: repositories and SQLite live on a single ReadWriteOnce volume. Pods run
with a read-only root filesystem and all capabilities dropped; everything Gogs writes
is under `/data`.

The release gate installs the chart on kind, gets an API token as the admin, creates a
repository, clones and pushes to it over HTTP (the push runs Gogs' server-side hooks),
checks the SSH server answers, recreates the pod and reads the pushed file back.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

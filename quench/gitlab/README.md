# Quenchworks GitLab CE

Hardened [GitLab CE](https://gitlab.com/gitlab-org/gitlab-foss) 19.6: the Git forge, issues, merge requests and CI/CD
front end. Four QuenchWorks images, all built from source on Wolfi, CVE-gated at build, cosign-signed and pinned by
digest:

| Component | Image | Runs |
|---|---|---|
| webservice | `gitlab-rails` + `gitlab-workhorse` | Puma behind Workhorse (HTTP, Git over HTTP, uploads) |
| sidekiq | `gitlab-rails` | background jobs (`bin/sidekiq-cluster`) |
| migrations | `gitlab-rails` | `rake gitlab:db:configure`, a Job per Helm revision |
| gitaly | `gitaly` | Git storage over gRPC, repositories on a PVC |
| gitlab-shell | `gitlab-shell` | Git over SSH (gitlab-sshd) |

The chart runs on the bundled QuenchWorks PostgreSQL and Valkey, and generates every secret once (Rails key bases,
Active Record encryption keys, the OpenID Connect signing key, the Workhorse, gitlab-shell and Gitaly tokens, the SSH
host keys and the initial root password), keeping them across upgrades.

The gitlab-rails image documents the advisories it does not fix by upgrade in a VEX statement (gems GitLab pins on old
majors, checked against GitLab's own code) and backports the devise 5.0 security fixes onto the devise 4.9 GitLab
locks.

## Install

```bash
helm install gitlab oci://ghcr.io/quenchworks/charts/gitlab --set gitlab.host=gitlab.example.com
```

Then read the root password from the chart Secret (see the install notes) and sign in.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `gitlab.host` | `gitlab.example.com` | Hostname users reach GitLab at, required |
| `gitlab.https` | `false` | Set when TLS terminates in front |
| `gitlab.monitoringAllowlist` | private ranges | CIDRs that may call the health endpoints the probes use |
| `webservice.puma.workers` | `2` | Puma workers per pod |
| `sidekiq.processes` | `["*"]` | One sidekiq process per entry; each a queue selector |
| `gitaly.persistence.size` | `10Gi` | Repository storage |
| `shared.persistence.size` | `10Gi` | Uploads, artifacts, LFS, packages (kept on uninstall) |
| `gitlabShell.service.type` | `ClusterIP` | Use `LoadBalancer` to expose SSH |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` (needs `max_locks_per_transaction` >= 512) |
| `valkey.enabled` | `true` | Or `externalRedis.url` |
| `secrets.existingSecret` | `""` | Bring every key yourself (same key names as the generated Secret) |

Uploads, CI artifacts, LFS objects and packages live on the `shared` PVC, mounted by webservice and sidekiq: with
pods on more than one node it needs a ReadWriteMany storage class (`shared.persistence.accessModes`). Not in this chart
yet: the container registry, Pages, KAS and object storage.

## Verify the images

```bash
for i in gitlab-rails gitlab-workhorse gitaly gitlab-shell; do
  cosign verify ghcr.io/quenchworks/images/$i \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

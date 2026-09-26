# gitlab-runner

GitLab Runner with the Kubernetes executor: it asks your GitLab instance for CI jobs
and runs each one as a pod in the cluster. The runner runs on the QuenchWorks image:
hardened, nonroot, 0-CVE, pinned by digest and cosign-signed.

## Install

Create a runner in GitLab (Settings > CI/CD > Runners > New project or group runner)
and copy its authentication token (`glrt-...`), then:

```sh
helm install ci oci://ghcr.io/quenchworks/charts/gitlab-runner \
  --set gitlabUrl=https://gitlab.example.com --set runner.token=glrt-...
```

The runner appears online in GitLab within a few seconds.

## How it runs

- **config.toml** is rendered into a Secret (it holds the token) and mounted as one
  file in a writable home directory, where the runner keeps `.runner_system_id`. Bring
  your own with `existingConfigSecret` (key `config.toml`).
- **Jobs** run as pods in `jobs.namespace` (default: the release namespace) under the
  runner's ServiceAccount, with a namespaced Role limited to what the executor uses:
  pods, exec/attach, logs, and the Secrets and ConfigMaps it creates per job.
- **Default job image** is the QuenchWorks busybox image, a shell for `script:`
  lines. Most pipelines set `image:` per job.
- **Helper image.** Each job pod also runs GitLab's helper container (clone, cache,
  artifacts), pulled from `registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper`
  at the runner's version. Set `jobs.helperImage` to use a mirror.
- **One replica per token.** Scale with `concurrent`, not replicas: two pods with the
  same token compete for jobs.

## Values

| Key | Default | Meaning |
|---|---|---|
| `gitlabUrl` | `""` | your GitLab (required) |
| `runner.token` | `""` | runner authentication token (required) |
| `concurrent` | `4` | jobs at once |
| `jobs.namespace` | release namespace | where job pods run |
| `jobs.image` | QuenchWorks busybox | default job image |
| `jobs.helperImage` | GitLab's | helper container image |
| `jobs.cpuLimit` / `jobs.memoryLimit` | `""` | per-job limits |

## Release gate

On kind, with a token for a GitLab that does not exist, the gate requires the runner
to start, report 19.4.1 on its metrics listener, keep running without restarts, and
its ServiceAccount to be allowed to create job pods in its namespace and not in
kube-system. Running a real job needs a GitLab instance and is not part of the gate.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.

# Quenchworks Concourse

Hardened [Concourse CI](https://concourse-ci.org/) on a 0-CVE image built from the release
tag. One binary runs in two roles:

- **web**: the API, the embedded UI (port 8080) and the TSA (port 2222). Nonroot uid 1001
  on a read-only rootfs.
- **worker**: runs your tasks with containerd. It needs root in a privileged pod, which
  this chart runs as a StatefulSet. Workers dial the TSA and register; the web node
  reaches them back through that SSH tunnel, so workers need no Service.

The chart bundles the Quenchworks PostgreSQL chart. Concourse reads the database password
from PostgreSQL's own Secret.

## Install

```bash
helm install ci oci://ghcr.io/quenchworks/charts/concourse \
  --set web.externalUrl=https://ci.example.com
kubectl get secret ci-concourse -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/ci-concourse 8080:8080
fly -t main login -c http://127.0.0.1:8080 -u admin
```

## Keys

A pre-install and pre-upgrade hook Job runs `concourse generate-key` for the session
signing key, the TSA host key and the worker key, and stores them in
`<release>-concourse-keys`. It creates that Secret only when it is missing, so an upgrade
never rotates keys under running workers. The Secret is not a Helm object: it survives
`helm uninstall`. Delete it by hand to rotate the keys, then restart web and workers.

## Resource types

Workers bundle `registry-image` and `time`, built from their release tags. The git
resource type is its own image; declare it in a pipeline:

```yaml
resource_types:
  - name: git
    type: registry-image
    source:
      repository: ghcr.io/quenchworks/images/concourse-git-resource
      tag: "1.23.0"
```

## Values that matter

| Key | Default | Meaning |
|---|---|---|
| `web.externalUrl` | `http://localhost:8080` | URL users and fly reach the web node at |
| `web.admin.username` / `password` | `admin` / generated | Local user, owner of the main team |
| `web.env` | `[]` | Extra `CONCOURSE_*` settings (auth providers, retention) |
| `worker.replicaCount` | `1` | Workers |
| `worker.workDir.persistence` | `false` | PVC per worker instead of an emptyDir |
| `worker.dnsProxy` | `true` | Task containers resolve through the worker's resolver (cluster DNS) |
| `postgresql.enabled` | `true` | Bundled PostgreSQL; false uses `externalDatabase.*` |

## Node requirement: unprivileged user namespaces

Tasks and resource checks run in unprivileged containers inside a user namespace. Nodes
that restrict unprivileged user namespaces, such as Ubuntu 24.04 with its default
`kernel.apparmor_restrict_unprivileged_userns=1`, make runc fail with `error mounting
"sysfs" to rootfs at "/sys": operation not permitted`. On those worker nodes set:

```bash
sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

## Security notes

The worker pod is privileged and runs as root: containerd creates containers, cgroups and
network namespaces. Run workers on nodes you are willing to give that to, for example with
`nodeSelector` and `tolerations`. The web node keeps the catalog's nonroot, read-only
defaults.

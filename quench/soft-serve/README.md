# Soft Serve

[Soft Serve](https://github.com/charmbracelet/soft-serve), a self-hostable Git server from Charm: Git over SSH, HTTP and
the git daemon, an SSH TUI for browsing, users and collaborators with access levels, and Git LFS. The image is built
from source by QuenchWorks, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install git oci://ghcr.io/quenchworks/charts/soft-serve --set-string "initialAdminKeys[0]=$(cat ~/.ssh/id_ed25519.pub)"
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `initialAdminKeys` | `[]` | SSH public keys of the admins created on the first start. |
| `anonAccess` | `read-only` | `no-access`, `read-only`, `read-write` or `admin-access` for anonymous users. |
| `allowKeyless` | `true` | Access without an SSH key (HTTP, the git daemon). |
| `publicUrl.ssh`, `.http` | Service names | The URLs shown in clone commands. |
| `service.ports.*` | 23231, 23232, 9418, 23233 | SSH, HTTP, the git daemon, stats. |
| `persistence.*` | 10Gi RWO | Repositories, the sqlite database, server keys. One replica. |

Git over SSH needs a LoadBalancer or NodePort Service; an Ingress carries the HTTP transport only.

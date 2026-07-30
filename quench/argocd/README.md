# Quenchworks Argo CD

Hardened [Argo CD](https://github.com/argoproj/argo-cd), the declarative GitOps
continuous-delivery controller for Kubernetes, on a minimal, nonroot, 0-CVE image
built from source, cosign-signed and pinned by digest.

Ships the API server **with its embedded React console**, the repo server, the
application controller and the applicationset controller — all from a single
multi-call image — plus clean-room RBAC and Redis from the catalog's own
[`quench/redis`](../redis) chart.

## Install

```bash
helm install argocd oci://ghcr.io/quenchworks/charts/argocd \
  --namespace argocd --create-namespace
```

```bash
# initial admin password (Argo CD generates it on first start)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo

kubectl -n argocd port-forward svc/argocd-argocd-server 8080:8080
# https://localhost:8080  (self-signed on first start; see server.insecure)
```

```bash
argocd repo add https://github.com/argoproj/argocd-example-apps.git
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
```

## One image, every component

Argo CD is a *multi-call binary*: `cmd/main.go` switches on
`filepath.Base(os.Args[0])`, so one `argocd` executable is the API server, the repo
server, the application controller, the applicationset controller, the notifications
controller, the CMP server, the commit server, the `argocd-dex` config shim, the
git-ask-pass helper **and** the `argocd` CLI. The image ships `/usr/bin/argocd` plus
a symlink per component, exactly as upstream's Dockerfile does, and each workload
selects its role with `command: [argocd-server]`. `ARGOCD_BINARY_NAME` is the
documented override if you ever need it.

One image, one digest, five workloads.

## The web console is really in there

The API server serves the React SPA out of `ui/dist/app`, embedded with
`//go:embed dist/app`. The catch: the release tarball already contains a
`ui/dist/app/gitkeep` placeholder, so **`go build` succeeds without a UI** and
produces a server that 404s every console route. There is no upstream "no-UI" build
tag — that placeholder is the only stub there is, which makes a broken console the
*default* failure mode for anyone repackaging Argo CD from source.

So the image build runs upstream's own asset pipeline (`yarn install` +
`webpack --mode production`, per architecture) and then asserts a real bundle
landed. Two independent checks guard it: the image test greps the embedded
`embed.FS` file names out of the binary and requires `index.html`, the resource
icons and ≥10 hashed js chunks; the chart's install gate fetches `/` from a running
server, requires the SPA `index.html`, and downloads the js bundle it references to
confirm it is >100 KB. Cost of shipping it: about 90s of build time and ~10 MB of
embedded assets. Worth it — Argo CD without its console is not Argo CD.

## Where the CRDs come from

`Application`, `ApplicationSet` and `AppProject` ship as **templates**
(`templates/crds/`), not in Helm's `crds/` directory. That is what upstream's own
argo-helm chart does, and here is why it is the right call:

* Helm applies `crds/` **once, on install, and never on upgrade**.
* Argo CD's `Application` and `ApplicationSet` schemas change on *every minor
  release* — all three currently supported lines (3.2 / 3.3 / 3.4) ship three
  different `Application` CRDs.
* So a `crds/`-shipped copy freezes at whatever version the cluster was first
  installed with, and every field added since is silently rejected by the API
  server. As templates they are reconciled by `helm upgrade` like anything else.

`crds.keep` (default `true`) puts `helm.sh/resource-policy: keep` on them, because
deleting these CRDs deletes every Application, ApplicationSet and AppProject in the
cluster. `helm uninstall` therefore leaves them behind, which is the behaviour you
want. Set `crds.install=false` if something else (a cluster bootstrap, an
App-of-Apps root) owns them.

## Components shipped, and what is not

| Component | Kind | Default | Why |
|---|---|---|---|
| `argocd-server` | Deployment | on | API + embedded web console. |
| `argocd-repo-server` | Deployment | on | Clones repos and renders manifests. |
| `argocd-application-controller` | **StatefulSet** | on | The reconciler. |
| `argocd-applicationset-controller` | Deployment | on | The chart installs the ApplicationSet CRD regardless; a CRD with no controller behind it looks broken, not disabled. |
| `argocd-notifications-controller` | Deployment | **off** | Does nothing until you write triggers into `notifications.cm`; no CRD, so its absence is invisible. |
| Redis | subchart | on | Hard dependency — see below. |
| Dex | — | **not shipped** | See below. |
| `argocd-commit-server` | — | not shipped | Only used by the alpha source hydrator. |

**Why the application controller is a StatefulSet.** Controller sharding assigns
clusters to shards by the pod's *ordinal*, parsed out of the pod name
(`…-application-controller-0`, `-1`, …). A Deployment's random pod suffixes have no
ordinal, so a scaled-out Deployment either needs the alpha dynamic-distribution
feature or silently double-reconciles. At one replica the two are identical; this
shape is the one that stays correct when `controller.replicaCount` goes up (raise
`ARGOCD_CONTROLLER_REPLICAS` with it — the chart does that for you).

**No Dex, deliberately.** Argo CD's dex component is not this image: upstream runs
the `ghcr.io/dexidp/dex` container and copies the argocd binary into it so
`argocd-dex rundex` can generate `/tmp/dex.yaml` and then `exec dex serve`. Bundling
it would mean a second image plus a copy-the-binary init container inside this
chart. It buys nothing for the common case, because Argo CD speaks OIDC directly:

```yaml
configs:
  url: https://argocd.example.com
  cm:
    oidc.config: |
      name: Okta
      issuer: https://example.okta.com
      clientID: <id>
      clientSecret: $oidc.okta.clientSecret
      requestedScopes: [openid, profile, email, groups]
  secret:
    extra:
      oidc.okta.clientSecret: <secret>
```

Only reach for Dex if you need its *connector translation* (LDAP, SAML, GitHub/GitLab
orgs) — run the separate [`quench/dex`](../dex) chart and point `oidc.config` at it.

## Redis

Redis is a **hard runtime dependency**, not an optional cache: the application
controller writes every resource tree and app state into it and the API server reads
them back, so without it the console shows nothing and syncs stall.

This chart depends on the catalog's own [`quench/redis`](../redis) chart rather than
vendoring a second Redis — same hardened 0-CVE image, same digest pinning, same
Sentinel HA path as everywhere else. Any `quench/redis` value can be set under the
`redis:` key. Password auth is on by default and the chart wires `REDIS_PASSWORD`
from the subchart's Secret into every component that talks to it.

Bring your own instead:

```yaml
redis:
  enabled: false
externalRedis:
  host: my-redis.data.svc.cluster.local
  port: 6379
  existingSecret: my-redis-auth
  existingSecretPasswordKey: password
```

## One Argo CD per namespace

Argo CD looks its own configuration up by **fixed name** (`common/common.go`):
`argocd-cm`, `argocd-rbac-cm`, `argocd-secret`, `argocd-ssh-known-hosts-cm`,
`argocd-tls-certs-cm`, `argocd-gpg-keys-cm`, `argocd-notifications-cm`,
`argocd-notifications-secret`. Those names are compiled in and not configurable, so
this chart emits them verbatim and **only one release can live in a namespace**.

Workloads, Services, ServiceAccounts and RBAC *are* release-prefixed, and every
cross-component address is passed as an explicit flag rather than relying on Argo
CD's built-in `argocd-repo-server:8081` / `argocd-redis:6379` defaults — which is
exactly what would otherwise cross-wire two releases in two namespaces.

**There is no `argocd-cmd-params-cm`.** Nothing in Argo CD reads it; upstream's
manifests wire ~50 `configMapKeyRef` entries out of it into `ARGOCD_*` environment
variables, and the binaries read the env vars. Rather than ship an object that looks
authoritative and does nothing, this chart exposes the same surface directly: typed
values for the common flags, `<component>.extraArgs` for the rest, and
`extraEnvVars` for the `ARGOCD_*` variables themselves.

```yaml
extraEnvVars:
  - name: ARGOCD_REPO_SERVER_PARALLELISM_LIMIT
    value: "10"
configs:
  cm:
    timeout.reconciliation: 300s      # the resync interval lives here, not in a flag
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/argocd@<digest> \
  --certificate-identity-regexp 'https://github.com/quenchworks/images/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/quenchworks/images/argocd@<digest> -R quenchworks/images
```

The image also carries a from-source **Helm 3** and the Wolfi **Kustomize** binary,
because `util/helm/cmd.go` and `util/kustomize/kustomize.go` exec them by bare name.
Helm is compiled in the same build with the same module float: the Wolfi `helm-3`
apk is frozen at 3.19.2 and scans with 100+ fixable CVEs, so it cannot pass the
0-CVE gate.

Unlike most Quenchworks images this one is **not shell-free**, and that is
unavoidable rather than sloppy: `util/gpg/gpg.go` execs `gpg-wrapper.sh` and
`util/git/client.go` execs `git-verify-wrapper.sh` — both upstream POSIX-sh scripts
on the commit-signature-verification path — and `git` itself shells out for
`GIT_SSH_COMMAND`, `core.askpass` and credential helpers. `busybox` is the smallest
thing that satisfies that, and it scans clean.

## Values

| Key | Default | Description |
|---|---|---|
| `image.repository` / `image.digest` | ghcr.io/quenchworks/images/argocd | Pinned by digest, never a tag. |
| `logFormat` / `logLevel` | `json` / `info` | Applied to every component. |
| `crds.install` / `crds.keep` | `true` / `true` | Ship the three CRDs as templates; keep them on uninstall. |
| `configs.url` | `""` | Externally reachable base URL. Required for OIDC callbacks, webhooks and notification links. |
| `configs.cm` | `{}` | `argocd-cm`, verbatim (`oidc.config`, `repositories`, `resource.exclusions`, `timeout.reconciliation`, …). |
| `configs.rbac.policyDefault` | `""` | Deliberately deny — a `role:readonly` default silently grants every SSO user read access to every app. |
| `configs.rbac.policyCsv` | `""` | `argocd-rbac-cm` policy. |
| `configs.sshKnownHosts` | `""` | Host keys for `ssh://` repos; the image symlinks `/etc/ssh/ssh_known_hosts` at it. |
| `configs.tlsCerts` / `configs.gpgKeys` | `{}` | CA bundles / public GPG keys, keyed by host / key id. |
| `configs.secret.argocdServerAdminPassword` | `""` | **bcrypt hash** (`argocd account bcrypt`), not plaintext. Empty → Argo CD generates `argocd-initial-admin-secret`. |
| `server.insecure` | `false` | `false` = the server terminates TLS with a per-session, in-memory self-signed cert (override by creating the `argocd-server-tls` Secret). `true` = plain HTTP behind an Ingress. Probes follow automatically. |
| `server.rootpath` | `""` | Serve the console under a sub-path (sets `--rootpath` and `--basehref`). |
| `server.service.type` / `.port` | `ClusterIP` / `8080` | |
| `repoServer.disableTLS` | `true` | Plaintext gRPC on a ClusterIP-only service; every caller is told with `--repo-server-plaintext`. |
| `repoServer.parallelismLimit` | `0` | Concurrent manifest generations; `0` = unlimited. |
| `repoServer.helmWorkingDirSizeLimit` | `1Gi` | emptyDir for `HELM_*_HOME`. Pure cache. |
| `controller.replicaCount` | `1` | Shards, not replicas — see above. |
| `controller.statusProcessors` / `.operationProcessors` | `""` | Worker pools; empty = upstream defaults. |
| `controller.shardingAlgorithm` | `""` | `legacy` \| `round-robin` \| `consistent-hashing`. Only meaningful above 1 replica. |
| `applicationSet.enabled` | `true` | |
| `notifications.enabled` | `false` | Always single-replica: no leader election, so a second replica double-sends. |
| `redis.enabled` | `true` | Bundled `quench/redis` subchart. |
| `externalRedis.host` | `""` | BYO Redis; wins over the subchart. |
| `rbac.create` | `true` | Namespaced Roles per component. |
| `rbac.clusterScoped` | `true` | Cluster-wide RBAC so Argo CD can manage its own cluster. |
| `serviceAccount.create` | `true` | One per component. |
| `networkPolicy.enabled` | `false` | Fences the repo server's gRPC port to this release's pods. |
| `<component>.resources` / `.extraArgs` | see `values.yaml` | Per-component. |
| `nodeSelector`, `affinity`, `tolerations`, `extraEnvVars`, … | | Chart-wide: they apply to **every** component. |

Full list with comments: [`values.yaml`](values.yaml). Schema:
[`values.schema.json`](values.schema.json).

## Security posture

* Every component: nonroot uid 1001, **read-only root filesystem**, all capabilities
  dropped, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault`.
* `argocd-repo-server` runs with `automountServiceAccountToken: false` — it never
  talks to the Kubernetes API, so a manifest-rendering RCE finds no cluster
  credentials to steal. It is also the only component fenced by the NetworkPolicy,
  because it holds every repository credential.
* One ServiceAccount per component. Their privilege levels differ by orders of
  magnitude: the application controller's ClusterRole is cluster-admin-equivalent
  *by construction* (applying arbitrary rendered manifests has no smaller permission
  set), while the internet-facing API server gets only `get`/`delete`/`patch` plus
  pod logs and Job/Workflow `create`. Collapsing them onto one account would hand the
  front door the controller's rights.
* `argocd-secret` carries `helm.sh/resource-policy: keep` and the chart declares only
  the keys you set. Helm patches Secrets rather than replacing them, so
  `server.secretkey` — which Argo CD writes there itself — survives `helm upgrade`.
  Declaring it empty would invalidate every session on every upgrade.

## Networking

| Port | Component | Purpose |
|---|---|---|
| 8080 | server | API + web console (`server.containerPort`) |
| 8083 | server | metrics |
| 8081 | repo-server | gRPC |
| 8084 | repo-server | metrics + `/healthz` |
| 8082 | application-controller | metrics + `/healthz` |
| 7000 | applicationset-controller | git-provider webhook |
| 8085 / 8086 | applicationset-controller | metrics / `/healthz`+`/readyz` |
| 9001 | notifications-controller | metrics |

The application controller's Service is **headless and required** — it is the
StatefulSet's `serviceName`, which is what gives the pods the stable ordinals
sharding keys off.

## Uninstall

```bash
helm uninstall argocd -n argocd
```

The three CRDs, `argocd-secret` and anything Argo CD wrote into it stay behind by
design. To remove them (and, with the CRDs, every Application, ApplicationSet and
AppProject in the cluster):

```bash
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
kubectl -n argocd delete secret argocd-secret
```

## Notes

* Clean-room chart: written from Argo CD's own upstream manifests and source, on the
  `quench-common` library chart. Not derived from any vendor's chart.
* Image built from source on Wolfi, multi-arch (amd64 + arm64), 0 fixable CVEs,
  cosign-signed with an SPDX SBOM and SLSA provenance attached.
* Upstream `hack/tool-versions.sh` asks for Helm 3.18/3.19; this image ships 3.21.3,
  the newest 3.x and the only patched option. Same CLI surface Argo CD drives
  (`template`, `dependency build`, `repo add`, `pull`, `version --short`).

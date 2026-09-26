# buildkit

BuildKit, the concurrent container image build engine behind `docker build`,
running **rootless**. buildkitd runs as uid 1001 inside a user namespace set up by
rootlesskit, on the QuenchWorks image: hardened, 0-CVE, pinned by digest and
cosign-signed.

## Install

```sh
helm install bk oci://ghcr.io/quenchworks/charts/buildkit
```

Build against it from a pod in the same namespace:

```sh
buildctl --addr tcp://bk-buildkit:1234 build \
  --frontend dockerfile.v0 --local context=. --local dockerfile=. \
  --output type=image,name=registry.example.com/app:1,push=true
```

Or register it with Docker Buildx:

```sh
docker buildx create --name quench --driver remote tcp://bk-buildkit:1234
```

## What rootless needs

The pod is not privileged and runs nothing as root on the node. It does need
three things the chart sets by default:

| Setting | Why |
|---|---|
| `seccompProfile: Unconfined`, `appArmorProfile: Unconfined` | the runtime profiles block the `unshare` and `mount` calls rootlesskit makes |
| `allowPrivilegeEscalation: true` | `newuidmap` is setuid; without it the bit is ignored |
| capabilities `drop: [ALL]`, `add: [SETUID, SETGID]` | the only capabilities `newuidmap` needs to write the subuid range |

`--oci-worker-no-process-sandbox` is on (`extraArgs`), as upstream recommends in
Kubernetes: a nested PID namespace needs a fresh `/proc` mount an unprivileged pod
cannot make. The root filesystem stays read-only; buildkitd writes only to its
cache, temp and runtime volumes.

A namespace enforcing the `restricted` Pod Security Standard rejects this pod.
`baseline` does not allow `Unconfined` seccomp either; label the namespace
`privileged` or exempt it.

## Security of the endpoint

A build endpoint runs whatever it is sent. Two controls:
- **NetworkPolicy** (on by default) admits only pods in the release namespace.
  `networkPolicy.allowExternal: true` opens it cluster-wide.
- **mTLS**: set `tls.existingSecret` to a Secret with `ca.crt`, `tls.crt` and
  `tls.key` (for example from cert-manager). buildkitd then only accepts clients
  with a certificate signed by that CA.

## Values

| Key | Default | Meaning |
|---|---|---|
| `service.port` | `1234` | gRPC endpoint |
| `tls.existingSecret` | `""` | Secret for mTLS; empty is plaintext |
| `persistence.enabled` | `false` | keep the build cache on a PVC instead of an emptyDir |
| `persistence.size` | `20Gi` | PVC size |
| `extraArgs` | `[--oci-worker-no-process-sandbox]` | extra buildkitd flags |
| `replicaCount` | `1` | independent daemons, each with its own cache |
| `networkPolicy.allowExternal` | `false` | admit clients from other namespaces |

The common production knobs (resources, scheduling, probes, extra volumes, sidecars)
come from `quench-common`.

## Release gate

On kind, the gate installs the chart with its default security context, then:
1. runs a Dockerfile build with a `RUN` step inside the daemon pod, and checks the
   step ran as root inside the build's user namespace;
2. connects a separate client pod over the Service and lists the workers.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
